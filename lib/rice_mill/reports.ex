defmodule RiceMill.Reports do
  @moduledoc """
  The Reports context for generating inventory reports.
  """

  import Ecto.Query, warn: false
  alias RiceMill.Repo
  alias RiceMill.Inventory.Product
  alias RiceMill.Inventory.StockIn
  alias RiceMill.Inventory.StockOut

  @doc """
  Returns current stock levels for all products in a tenant.

  Calculates available stock as: total stock-in minus total stock-out.

  ## Examples

      iex> current_stock_levels(tenant_id)
      [%{id: "...", name: "...", sku: "...", total_in: Decimal.new("100.500"),
         total_out: Decimal.new("20.000"), available_stock: Decimal.new("80.500")}, ...]

  """
  def current_stock_levels(tenant_id) when is_nil(tenant_id) do
    # Super admin with no tenant - return empty list
    []
  end

  def current_stock_levels(tenant_id) do
    Product
    |> where([p], p.tenant_id == ^tenant_id)
    |> join(:left, [p], sin in StockIn, on: sin.product_id == p.id)
    |> join(:left, [p], sout in StockOut, on: sout.product_id == p.id)
    |> group_by([p], [p.id, p.name, p.sku])
    |> select([p, sin, sout], %{
      id: p.id,
      name: p.name,
      sku: p.sku,
      total_in: coalesce(sum(sin.total_quintals), 0),
      total_out: coalesce(sum(sout.total_quintals), 0),
      available_stock:
        coalesce(sum(sin.total_quintals), 0) - coalesce(sum(sout.total_quintals), 0)
    })
    |> order_by([p], p.name)
    |> Repo.all()
  end

  @doc """
  Returns stock-in transaction history for a tenant with optional filters.

  Supports filtering by date range and farmer name.

  ## Examples

      iex> stock_in_history(tenant_id)
      [%StockIn{}, ...]

      iex> stock_in_history(tenant_id, %{date_from: ~D[2024-01-01], farmer_name: "John"})
      [%StockIn{}, ...]

  """
  def stock_in_history(tenant_id, filters \\ %{})

  def stock_in_history(tenant_id, _filters) when is_nil(tenant_id) do
    # Super admin with no tenant - return empty list
    []
  end

  def stock_in_history(tenant_id, filters) do
    StockIn
    |> where([s], s.tenant_id == ^tenant_id)
    |> apply_filters(filters)
    |> order_by([s], desc: s.date, desc: s.inserted_at)
    |> preload(:product)
    |> Repo.all()
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:date_from, date}, query when not is_nil(date) and date != "" ->
        where(query, [s], s.date >= ^date)

      {:date_to, date}, query when not is_nil(date) and date != "" ->
        where(query, [s], s.date <= ^date)

      {:farmer_name, name}, query when not is_nil(name) and name != "" ->
        where(query, [s], ilike(s.farmer_name, ^"%#{name}%"))

      _, query ->
        query
    end)
  end

  @doc """
  Returns stock-out transaction history for a tenant with optional filters.

  Supports filtering by date range and customer name.

  ## Examples

      iex> stock_out_history(tenant_id)
      [%StockOut{}, ...]

      iex> stock_out_history(tenant_id, %{date_from: ~D[2024-01-01], customer_name: "John"})
      [%StockOut{}, ...]

  """
  def stock_out_history(tenant_id, filters \\ %{})

  def stock_out_history(tenant_id, _filters) when is_nil(tenant_id) do
    # Super admin with no tenant - return empty list
    []
  end

  def stock_out_history(tenant_id, filters) do
    StockOut
    |> where([s], s.tenant_id == ^tenant_id)
    |> apply_stock_out_filters(filters)
    |> order_by([s], desc: s.date, desc: s.inserted_at)
    |> preload(:product)
    |> Repo.all()
  end

  defp apply_stock_out_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:date_from, date}, query when not is_nil(date) and date != "" ->
        where(query, [s], s.date >= ^date)

      {:date_to, date}, query when not is_nil(date) and date != "" ->
        where(query, [s], s.date <= ^date)

      {:customer_name, name}, query when not is_nil(name) and name != "" ->
        where(query, [s], ilike(s.customer_name, ^"%#{name}%"))

      _, query ->
        query
    end)
  end

  @doc """
  Returns combined transaction history (both stock-in and stock-out) for a tenant.

  Returns a list of maps with transaction details and type indicator.

  ## Examples

      iex> transaction_history(tenant_id)
      [%{type: :in, date: ~D[2024-01-01], ...}, %{type: :out, date: ~D[2024-01-02], ...}]

  """
  def transaction_history(tenant_id, filters \\ %{})

  def transaction_history(tenant_id, _filters) when is_nil(tenant_id) do
    []
  end

  def transaction_history(tenant_id, filters) do
    stock_ins = stock_in_history(tenant_id, filters)
    stock_outs = stock_out_history(tenant_id, filters)

    # Convert to unified format
    in_transactions =
      Enum.map(stock_ins, fn stock_in ->
        %{
          type: :in,
          id: stock_in.id,
          date: stock_in.date,
          product: stock_in.product,
          party_name: stock_in.farmer_name,
          party_contact: stock_in.farmer_contact,
          vehicle_number: stock_in.vehicle_number,
          total_quintals: stock_in.total_quintals,
          price_per_quintal: stock_in.price_per_quintal,
          total_price: stock_in.total_price,
          inserted_at: stock_in.inserted_at
        }
      end)

    out_transactions =
      Enum.map(stock_outs, fn stock_out ->
        %{
          type: :out,
          id: stock_out.id,
          date: stock_out.date,
          product: stock_out.product,
          party_name: stock_out.customer_name,
          party_contact: stock_out.customer_contact,
          vehicle_number: stock_out.vehicle_number,
          total_quintals: stock_out.total_quintals,
          price_per_quintal: stock_out.price_per_quintal,
          total_price: stock_out.total_price,
          inserted_at: stock_out.inserted_at
        }
      end)

    # Combine and sort by date (most recent first)
    (in_transactions ++ out_transactions)
    |> Enum.sort_by(&{&1.date, &1.inserted_at}, :desc)
  end
end
