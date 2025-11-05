defmodule RiceMill.Dashboard do
  @moduledoc """
  The Dashboard context for analytics and metrics.
  """

  import Ecto.Query
  alias RiceMill.Repo
  alias RiceMill.Inventory.{Product, StockIn, StockOut}

  @cache_ttl :timer.seconds(Application.compile_env(:rice_mill, :dashboard_cache_ttl_seconds, 30))

  # Helper function to get cached metrics with automatic cache management.
  defp get_cached_metrics(tenant_id, cache_key, fetch_fn) do
    full_cache_key = "#{tenant_id}:#{cache_key}"

    case Cachex.get(:dashboard_cache, full_cache_key) do
      {:ok, nil} ->
        result = fetch_fn.()
        Cachex.put(:dashboard_cache, full_cache_key, result, ttl: @cache_ttl)
        result

      {:ok, cached} ->
        cached

      {:error, _} ->
        # If cache fails, just fetch directly
        fetch_fn.()
    end
  end

  @doc """
  Invalidates all cached metrics for a tenant.
  """
  def invalidate_cache(tenant_id) do
    # Get all keys for this tenant
    {:ok, keys} = Cachex.keys(:dashboard_cache)

    tenant_prefix = "#{tenant_id}:"

    keys
    |> Enum.filter(&String.starts_with?(&1, tenant_prefix))
    |> Enum.each(&Cachex.del(:dashboard_cache, &1))

    :ok
  end

  @doc """
  Returns inventory metrics including total stock, product count, and total value.
  """
  def get_inventory_metrics(tenant_id) do
    get_cached_metrics(tenant_id, "inventory_metrics", fn ->
      fetch_inventory_metrics(tenant_id)
    end)
  end

  defp fetch_inventory_metrics(tenant_id) do
    # Optimized query: Calculate all metrics in a single database query using subqueries
    # This reduces round trips and performs aggregation in the database
    stock_in_query =
      from s in StockIn,
        where: s.tenant_id == ^tenant_id,
        group_by: s.product_id,
        select: %{product_id: s.product_id, total_in: sum(s.total_quintals)}

    stock_out_query =
      from s in StockOut,
        where: s.tenant_id == ^tenant_id,
        group_by: s.product_id,
        select: %{product_id: s.product_id, total_out: sum(s.total_quintals)}

    # Single query to calculate all metrics using database aggregation
    metrics =
      from p in Product,
        left_join: si in subquery(stock_in_query),
        on: p.id == si.product_id,
        left_join: so in subquery(stock_out_query),
        on: p.id == so.product_id,
        where: p.tenant_id == ^tenant_id,
        select: %{
          total_stock: sum(coalesce(si.total_in, 0) - coalesce(so.total_out, 0)),
          product_count:
            count(
              fragment(
                "CASE WHEN (COALESCE(?, 0) - COALESCE(?, 0)) > 0 THEN 1 END",
                si.total_in,
                so.total_out
              )
            ),
          inventory_value:
            sum(
              fragment(
                "(COALESCE(?, 0) - COALESCE(?, 0)) * ?",
                si.total_in,
                so.total_out,
                p.price_per_quintal
              )
            )
        }

    result = Repo.one(metrics)

    %{
      total_stock: result.total_stock || Decimal.new(0),
      product_count: result.product_count || 0,
      total_value: result.inventory_value || Decimal.new(0)
    }
  end

  @doc """
  Returns financial metrics for the given date range.
  """
  def get_financial_metrics(tenant_id, {start_date, end_date}) do
    cache_key = "financial_metrics:#{start_date}:#{end_date}"

    get_cached_metrics(tenant_id, cache_key, fn ->
      fetch_financial_metrics(tenant_id, {start_date, end_date})
    end)
  end

  defp fetch_financial_metrics(tenant_id, {start_date, end_date}) do
    # Optimized: Use database aggregation for all calculations
    purchase_metrics =
      from(s in StockIn,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^start_date and s.date <= ^end_date,
        select: %{
          total: sum(s.total_price),
          count: count(s.id)
        }
      )
      |> Repo.one()

    sales_metrics =
      from(s in StockOut,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^start_date and s.date <= ^end_date,
        select: %{
          total: sum(s.total_price),
          count: count(s.id)
        }
      )
      |> Repo.one()

    total_purchases = purchase_metrics.total || Decimal.new(0)
    total_sales = sales_metrics.total || Decimal.new(0)
    gross_margin = Decimal.sub(total_sales, total_purchases)

    %{
      total_purchases: total_purchases,
      total_sales: total_sales,
      gross_margin: gross_margin,
      stock_in_count: purchase_metrics.count || 0,
      stock_out_count: sales_metrics.count || 0
    }
  end

  @doc """
  Returns recent stock-in transactions.
  Optimized: Uses join instead of preload and selects only required fields.
  """
  def get_recent_stock_ins(tenant_id, limit \\ 10) do
    from(s in StockIn,
      join: p in Product,
      on: s.product_id == p.id,
      where: s.tenant_id == ^tenant_id,
      order_by: [desc: s.date, desc: s.inserted_at],
      limit: ^limit,
      select: %{
        id: s.id,
        date: s.date,
        farmer_name: s.farmer_name,
        total_quintals: s.total_quintals,
        total_price: s.total_price,
        inserted_at: s.inserted_at,
        product_name: p.name
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns recent stock-out transactions.
  Optimized: Uses join instead of preload and selects only required fields.
  """
  def get_recent_stock_outs(tenant_id, limit \\ 10) do
    from(s in StockOut,
      join: p in Product,
      on: s.product_id == p.id,
      where: s.tenant_id == ^tenant_id,
      order_by: [desc: s.date, desc: s.inserted_at],
      limit: ^limit,
      select: %{
        id: s.id,
        date: s.date,
        customer_name: s.customer_name,
        total_quintals: s.total_quintals,
        total_price: s.total_price,
        inserted_at: s.inserted_at,
        product_name: p.name
      }
    )
    |> Repo.all()
  end

  @doc """
  Returns stock movement data for charting.
  """
  def get_stock_movement_data(tenant_id, {start_date, end_date}) do
    cache_key = "stock_movement:#{start_date}:#{end_date}"

    get_cached_metrics(tenant_id, cache_key, fn ->
      fetch_stock_movement_data(tenant_id, {start_date, end_date})
    end)
  end

  defp fetch_stock_movement_data(tenant_id, {start_date, end_date}) do
    # Optimized: Use database aggregation for grouping by date
    stock_in_by_date =
      from(s in StockIn,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^start_date and s.date <= ^end_date,
        group_by: s.date,
        select: %{date: s.date, total: sum(s.total_quintals)}
      )
      |> Repo.all()
      |> Map.new(&{&1.date, &1.total})

    stock_out_by_date =
      from(s in StockOut,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^start_date and s.date <= ^end_date,
        group_by: s.date,
        select: %{date: s.date, total: sum(s.total_quintals)}
      )
      |> Repo.all()
      |> Map.new(&{&1.date, &1.total})

    # Generate all dates in range
    date_range = Date.range(start_date, end_date)
    dates = Enum.to_list(date_range)

    # Fill missing dates with zero values
    stock_in_values =
      Enum.map(dates, fn date ->
        Map.get(stock_in_by_date, date, Decimal.new(0))
      end)

    stock_out_values =
      Enum.map(dates, fn date ->
        Map.get(stock_out_by_date, date, Decimal.new(0))
      end)

    %{
      dates: dates,
      stock_in_values: stock_in_values,
      stock_out_values: stock_out_values
    }
  end

  @doc """
  Returns top products by volume for the date range.
  """
  def get_top_products(tenant_id, {start_date, end_date}) do
    cache_key = "top_products:#{start_date}:#{end_date}"

    get_cached_metrics(tenant_id, cache_key, fn ->
      fetch_top_products(tenant_id, {start_date, end_date})
    end)
  end

  defp fetch_top_products(tenant_id, {start_date, end_date}) do
    # Optimized: Calculate percentages in the database using window functions
    # This eliminates the need for post-processing in Elixir

    # Query top 5 products by stock-in volume
    stock_in_products =
      from(s in StockIn,
        join: p in Product,
        on: s.product_id == p.id,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^start_date and s.date <= ^end_date,
        group_by: [s.product_id, p.name],
        select: %{
          product_id: s.product_id,
          product_name: p.name,
          quantity: sum(s.total_quintals),
          type: "stock_in"
        },
        order_by: [desc: sum(s.total_quintals)],
        limit: 5
      )
      |> Repo.all()

    # Calculate total and percentages in Elixir (more reliable than window functions with GROUP BY)
    total_stock_in =
      stock_in_products
      |> Enum.map(& &1.quantity)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    stock_in_with_percentage =
      Enum.map(stock_in_products, fn product ->
        percentage =
          if Decimal.compare(total_stock_in, 0) == :gt do
            product.quantity
            |> Decimal.div(total_stock_in)
            |> Decimal.mult(100)
            |> Decimal.round(2)
          else
            Decimal.new(0)
          end

        Map.put(product, :percentage, percentage)
      end)

    # Query top 5 products by stock-out volume
    stock_out_products =
      from(s in StockOut,
        join: p in Product,
        on: s.product_id == p.id,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^start_date and s.date <= ^end_date,
        group_by: [s.product_id, p.name],
        select: %{
          product_id: s.product_id,
          product_name: p.name,
          quantity: sum(s.total_quintals),
          type: "stock_out"
        },
        order_by: [desc: sum(s.total_quintals)],
        limit: 5
      )
      |> Repo.all()

    # Calculate total and percentages in Elixir
    total_stock_out =
      stock_out_products
      |> Enum.map(& &1.quantity)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    stock_out_with_percentage =
      Enum.map(stock_out_products, fn product ->
        percentage =
          if Decimal.compare(total_stock_out, 0) == :gt do
            product.quantity
            |> Decimal.div(total_stock_out)
            |> Decimal.mult(100)
            |> Decimal.round(2)
          else
            Decimal.new(0)
          end

        Map.put(product, :percentage, percentage)
      end)

    %{
      stock_in: stock_in_with_percentage,
      stock_out: stock_out_with_percentage
    }
  end

  @doc """
  Returns top farmers by purchase volume.
  """
  def get_top_farmers(tenant_id, {start_date, end_date}) do
    cache_key = "top_farmers:#{start_date}:#{end_date}"

    get_cached_metrics(tenant_id, cache_key, fn ->
      fetch_top_farmers(tenant_id, {start_date, end_date})
    end)
  end

  defp fetch_top_farmers(tenant_id, {start_date, end_date}) do
    # Optimized: Select only required fields and perform all aggregation in database
    from(s in StockIn,
      where: s.tenant_id == ^tenant_id,
      where: s.date >= ^start_date and s.date <= ^end_date,
      group_by: s.farmer_name,
      select: %{
        farmer_name: s.farmer_name,
        total_quantity: sum(s.total_quintals),
        total_amount: sum(s.total_price),
        transaction_count: count(s.id),
        average_transaction_size: avg(s.total_quintals)
      },
      order_by: [desc: sum(s.total_quintals)],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Returns top customers by sales volume.
  """
  def get_top_customers(tenant_id, {start_date, end_date}) do
    cache_key = "top_customers:#{start_date}:#{end_date}"

    get_cached_metrics(tenant_id, cache_key, fn ->
      fetch_top_customers(tenant_id, {start_date, end_date})
    end)
  end

  defp fetch_top_customers(tenant_id, {start_date, end_date}) do
    # Optimized: Select only required fields and perform all aggregation in database
    from(s in StockOut,
      where: s.tenant_id == ^tenant_id,
      where: s.date >= ^start_date and s.date <= ^end_date,
      group_by: s.customer_name,
      select: %{
        customer_name: s.customer_name,
        total_quantity: sum(s.total_quintals),
        total_amount: sum(s.total_price),
        transaction_count: count(s.id),
        average_transaction_size: avg(s.total_quintals)
      },
      order_by: [desc: sum(s.total_quintals)],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Returns stock alerts for low and out-of-stock products.
  """
  def get_stock_alerts(tenant_id) do
    get_cached_metrics(tenant_id, "stock_alerts", fn ->
      fetch_stock_alerts(tenant_id)
    end)
  end

  defp fetch_stock_alerts(tenant_id) do
    # Get low stock threshold from config
    threshold = Application.get_env(:rice_mill, :low_stock_threshold, 50)

    # Optimized: Filter and calculate severity in database, reducing application processing
    stock_in_query =
      from s in StockIn,
        where: s.tenant_id == ^tenant_id,
        group_by: s.product_id,
        select: %{product_id: s.product_id, total_in: sum(s.total_quintals)}

    stock_out_query =
      from s in StockOut,
        where: s.tenant_id == ^tenant_id,
        group_by: s.product_id,
        select: %{product_id: s.product_id, total_out: sum(s.total_quintals)}

    # Calculate net stock, filter for alerts, and determine severity in database
    from(p in Product,
      left_join: si in subquery(stock_in_query),
      on: p.id == si.product_id,
      left_join: so in subquery(stock_out_query),
      on: p.id == so.product_id,
      where: p.tenant_id == ^tenant_id,
      select: %{
        product_id: p.id,
        product_name: p.name,
        current_stock: coalesce(si.total_in, 0) - coalesce(so.total_out, 0),
        severity:
          fragment(
            "CASE WHEN (COALESCE(?, 0) - COALESCE(?, 0)) = 0 THEN 'out_of_stock' ELSE 'low_stock' END",
            si.total_in,
            so.total_out
          )
      },
      where:
        fragment(
          "(COALESCE(?, 0) - COALESCE(?, 0)) < ?",
          si.total_in,
          so.total_out,
          ^threshold
        ),
      order_by: [asc: coalesce(si.total_in, 0) - coalesce(so.total_out, 0)]
    )
    |> Repo.all()
    |> Enum.map(fn product ->
      Map.update!(product, :severity, fn
        "out_of_stock" -> :out_of_stock
        "low_stock" -> :low_stock
      end)
    end)
  end

  @doc """
  Returns performance comparison between current and previous period.
  """
  def get_performance_comparison(tenant_id, {start_date, end_date}) do
    cache_key = "performance_comparison:#{start_date}:#{end_date}"

    get_cached_metrics(tenant_id, cache_key, fn ->
      fetch_performance_comparison(tenant_id, {start_date, end_date})
    end)
  end

  defp fetch_performance_comparison(tenant_id, {start_date, end_date}) do
    # Optimized: Combine all 4 queries into a single query using UNION ALL
    # This reduces database round trips from 4 to 1
    {prev_start, prev_end} = calculate_previous_period({start_date, end_date})

    # Current period stock-in
    current_stock_in_query =
      from s in StockIn,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^start_date and s.date <= ^end_date,
        select: %{
          current_stock_in: sum(s.total_quintals),
          current_stock_out: fragment("0::numeric"),
          previous_stock_in: fragment("0::numeric"),
          previous_stock_out: fragment("0::numeric")
        }

    # Current period stock-out
    current_stock_out_query =
      from s in StockOut,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^start_date and s.date <= ^end_date,
        select: %{
          current_stock_in: fragment("0::numeric"),
          current_stock_out: sum(s.total_quintals),
          previous_stock_in: fragment("0::numeric"),
          previous_stock_out: fragment("0::numeric")
        }

    # Previous period stock-in
    previous_stock_in_query =
      from s in StockIn,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^prev_start and s.date <= ^prev_end,
        select: %{
          current_stock_in: fragment("0::numeric"),
          current_stock_out: fragment("0::numeric"),
          previous_stock_in: sum(s.total_quintals),
          previous_stock_out: fragment("0::numeric")
        }

    # Previous period stock-out
    previous_stock_out_query =
      from s in StockOut,
        where: s.tenant_id == ^tenant_id,
        where: s.date >= ^prev_start and s.date <= ^prev_end,
        select: %{
          current_stock_in: fragment("0::numeric"),
          current_stock_out: fragment("0::numeric"),
          previous_stock_in: fragment("0::numeric"),
          previous_stock_out: sum(s.total_quintals)
        }

    # Combine all queries and aggregate
    combined_query =
      current_stock_in_query
      |> union_all(^current_stock_out_query)
      |> union_all(^previous_stock_in_query)
      |> union_all(^previous_stock_out_query)

    result =
      from u in subquery(combined_query),
        select: %{
          current_stock_in: sum(u.current_stock_in),
          current_stock_out: sum(u.current_stock_out),
          previous_stock_in: sum(u.previous_stock_in),
          previous_stock_out: sum(u.previous_stock_out)
        }

    metrics = Repo.one(result)

    current_stock_in = metrics.current_stock_in || Decimal.new(0)
    current_stock_out = metrics.current_stock_out || Decimal.new(0)
    previous_stock_in = metrics.previous_stock_in || Decimal.new(0)
    previous_stock_out = metrics.previous_stock_out || Decimal.new(0)

    # Calculate percentage changes
    stock_in_change = calculate_percentage_change(previous_stock_in, current_stock_in)
    stock_out_change = calculate_percentage_change(previous_stock_out, current_stock_out)

    %{
      current_stock_in: current_stock_in,
      current_stock_out: current_stock_out,
      previous_stock_in: previous_stock_in,
      previous_stock_out: previous_stock_out,
      stock_in_change: stock_in_change,
      stock_out_change: stock_out_change
    }
  end

  # Helper function to calculate percentage change
  defp calculate_percentage_change(previous, current) do
    cond do
      Decimal.compare(previous, 0) == :eq and Decimal.compare(current, 0) == :eq ->
        Decimal.new(0)

      Decimal.compare(previous, 0) == :eq ->
        Decimal.new(100)

      true ->
        current
        |> Decimal.sub(previous)
        |> Decimal.div(previous)
        |> Decimal.mult(100)
        |> Decimal.round(2)
    end
  end

  @doc """
  Calculates date range from time period string.
  """
  def calculate_date_range("today"), do: {Date.utc_today(), Date.utc_today()}

  def calculate_date_range("this_week") do
    today = Date.utc_today()
    start_of_week = Date.beginning_of_week(today)
    {start_of_week, today}
  end

  def calculate_date_range("this_month") do
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    {start_of_month, today}
  end

  def calculate_date_range("last_month") do
    today = Date.utc_today()
    last_month = Date.add(today, -30)
    start_of_last_month = Date.beginning_of_month(last_month)
    end_of_last_month = Date.end_of_month(last_month)
    {start_of_last_month, end_of_last_month}
  end

  def calculate_date_range("this_quarter") do
    today = Date.utc_today()
    month = today.month
    quarter_start_month = div(month - 1, 3) * 3 + 1
    quarter_start = %{today | month: quarter_start_month, day: 1}
    {quarter_start, today}
  end

  def calculate_date_range("this_year") do
    today = Date.utc_today()
    year_start = %{today | month: 1, day: 1}
    {year_start, today}
  end

  def calculate_date_range(_), do: calculate_date_range("this_month")

  @doc """
  Calculates the previous period equivalent to the given date range.
  """
  def calculate_previous_period({start_date, end_date}) do
    days_diff = Date.diff(end_date, start_date)
    prev_end = Date.add(start_date, -1)
    prev_start = Date.add(prev_end, -days_diff)
    {prev_start, prev_end}
  end

  # Dashboard Preferences Functions

  alias RiceMill.Dashboard.DashboardPreference

  @doc """
  Gets or creates dashboard preferences for a user.
  """
  def get_or_create_preferences(user_id) do
    case Repo.get_by(DashboardPreference, user_id: user_id) do
      nil ->
        %DashboardPreference{user_id: user_id}
        |> DashboardPreference.changeset(%{})
        |> Repo.insert()

      preference ->
        {:ok, preference}
    end
  end

  @doc """
  Updates widget order for a user.
  """
  def update_widget_order(user_id, widget_order) do
    {:ok, preference} = get_or_create_preferences(user_id)

    preference
    |> DashboardPreference.changeset(%{widget_order: widget_order})
    |> Repo.update()
  end

  @doc """
  Toggles widget visibility for a user.
  """
  def toggle_widget_visibility(user_id, widget_name) do
    {:ok, preference} = get_or_create_preferences(user_id)

    hidden_widgets =
      if widget_name in preference.hidden_widgets do
        List.delete(preference.hidden_widgets, widget_name)
      else
        [widget_name | preference.hidden_widgets]
      end

    preference
    |> DashboardPreference.changeset(%{hidden_widgets: hidden_widgets})
    |> Repo.update()
  end

  @doc """
  Resets dashboard layout to default for a user.
  """
  def reset_layout(user_id) do
    case Repo.get_by(DashboardPreference, user_id: user_id) do
      nil ->
        {:ok, nil}

      preference ->
        preference
        |> DashboardPreference.changeset(%{widget_order: [], hidden_widgets: []})
        |> Repo.update()
    end
  end
end
