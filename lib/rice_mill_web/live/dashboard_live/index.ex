defmodule RiceMillWeb.DashboardLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    tenant_id = user.tenant_id

    # Verify user role - all authenticated users can access dashboard
    # but viewer role will have restricted access to certain features
    if user.role not in [:super_admin, :company_admin, :operator, :viewer] do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access the dashboard")
       |> redirect(to: ~p"/")}
    else
      if connected?(socket) do
        # Subscribe to real-time updates for transactions and products
        Phoenix.PubSub.subscribe(RiceMill.PubSub, "tenant:#{tenant_id}:transactions")
        Phoenix.PubSub.subscribe(RiceMill.PubSub, "tenant:#{tenant_id}:products")
      end

      # Load user preferences
      {:ok, preferences} = Dashboard.get_or_create_preferences(user.id)

      socket =
        socket
        |> assign(:time_period, "this_month")
        |> assign(:loading, true)
        |> assign(:page_title, "Dashboard")
        |> assign(:user_role, user.role)
        |> assign(:can_view_financial, can_view_financial?(user.role))
        |> assign(:can_perform_actions, can_perform_actions?(user.role))
        |> assign(:preferences, preferences)
        |> assign(:widget_order, preferences.widget_order)
        |> assign(:hidden_widgets, preferences.hidden_widgets)
        |> assign(:customization_mode, false)
        |> assign(:widget_errors, %{})
        |> load_dashboard_data()

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    socket =
      socket
      |> assign(:time_period, period)
      |> assign(:loading, true)
      |> load_dashboard_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("export_dashboard", _params, socket) do
    # This event is no longer needed since we're using a direct link
    {:noreply, socket}
  end

  @impl true
  def handle_event("reorder_widgets", %{"order" => order}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Dashboard.update_widget_order(user_id, order) do
      {:ok, preference} ->
        socket =
          socket
          |> assign(:widget_order, preference.widget_order)
          |> put_flash(:info, "Widget order saved")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to save widget order")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_customization", _params, socket) do
    {:noreply, assign(socket, :customization_mode, !socket.assigns.customization_mode)}
  end

  @impl true
  def handle_event("toggle_widget", %{"widget" => widget_name}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Dashboard.toggle_widget_visibility(user_id, widget_name) do
      {:ok, preference} ->
        socket =
          socket
          |> assign(:hidden_widgets, preference.hidden_widgets)
          |> put_flash(:info, "Widget visibility updated")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to update widget visibility")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_widget", %{"widget" => widget_name}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Dashboard.toggle_widget_visibility(user_id, widget_name) do
      {:ok, preference} ->
        socket =
          socket
          |> assign(:hidden_widgets, preference.hidden_widgets)
          |> put_flash(:info, "Widget shown")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to show widget")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset_layout", _params, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Dashboard.reset_layout(user_id) do
      {:ok, _preference} ->
        socket =
          socket
          |> assign(:widget_order, [])
          |> assign(:hidden_widgets, [])
          |> assign(:customization_mode, false)
          |> put_flash(:info, "Dashboard layout reset to default")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to reset dashboard layout")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_reset", _params, socket) do
    # This will be handled by the JS confirmation
    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_widget", %{"widget" => widget_name}, socket) do
    socket =
      socket
      |> assign(:widget_errors, Map.delete(socket.assigns.widget_errors, widget_name))
      |> load_widget_data(widget_name)

    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_all", _params, socket) do
    socket =
      socket
      |> assign(:widget_errors, %{})
      |> assign(:loading, true)
      |> load_dashboard_data()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:transaction_created, _transaction}, socket) do
    # Reload dashboard data when a transaction is created
    {:noreply, load_dashboard_data(socket)}
  end

  @impl true
  def handle_info({:product_updated, _product}, socket) do
    # Reload dashboard data when a product is updated
    {:noreply, load_dashboard_data(socket)}
  end

  defp load_dashboard_data(socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id
    user_role = socket.assigns.user_role
    time_period = socket.assigns.time_period
    date_range = Dashboard.calculate_date_range(time_period)

    widget_errors = %{}

    # Load inventory metrics
    {socket, widget_errors} =
      load_widget_safe(socket, widget_errors, "inventory_summary", fn ->
        Dashboard.get_inventory_metrics(tenant_id)
      end, :inventory_metrics)

    # Load recent transactions
    {socket, widget_errors} =
      load_widget_safe(socket, widget_errors, "recent_transactions", fn ->
        {Dashboard.get_recent_stock_ins(tenant_id, 10),
         Dashboard.get_recent_stock_outs(tenant_id, 10)}
      end, fn {stock_ins, stock_outs} ->
        [recent_stock_ins: stock_ins, recent_stock_outs: stock_outs]
      end)

    # Load stock movement data
    {socket, widget_errors} =
      load_widget_safe(socket, widget_errors, "stock_movement", fn ->
        Dashboard.get_stock_movement_data(tenant_id, date_range)
      end, :stock_movement_data)

    # Load top products
    {socket, widget_errors} =
      load_widget_safe(socket, widget_errors, "top_products", fn ->
        Dashboard.get_top_products(tenant_id, date_range)
      end, :top_products)

    # Load stock alerts
    {socket, widget_errors} =
      load_widget_safe(socket, widget_errors, "stock_alerts", fn ->
        Dashboard.get_stock_alerts(tenant_id)
      end, :stock_alerts)

    # Load performance comparison
    {socket, widget_errors} =
      load_widget_safe(socket, widget_errors, "performance_comparison", fn ->
        Dashboard.get_performance_comparison(tenant_id, date_range)
      end, :performance_comparison)

    # Load financial data only if user has permission
    {socket, widget_errors} =
      if widget_visible?(:financial_metrics, user_role) do
        {socket, widget_errors} =
          load_widget_safe(socket, widget_errors, "financial_metrics", fn ->
            Dashboard.get_financial_metrics(tenant_id, date_range)
          end, :financial_metrics)

        {socket, widget_errors} =
          load_widget_safe(socket, widget_errors, "farmer_activity", fn ->
            Dashboard.get_top_farmers(tenant_id, date_range)
          end, :top_farmers)

        {socket, widget_errors} =
          load_widget_safe(socket, widget_errors, "customer_activity", fn ->
            Dashboard.get_top_customers(tenant_id, date_range)
          end, :top_customers)

        {socket, widget_errors}
      else
        socket =
          socket
          |> assign(:financial_metrics, %{
            total_purchases: 0,
            total_sales: 0,
            gross_margin: 0,
            purchase_count: 0,
            sales_count: 0
          })
          |> assign(:top_farmers, [])
          |> assign(:top_customers, [])

        {socket, widget_errors}
      end

    socket
    |> assign(:loading, false)
    |> assign(:error, nil)
    |> assign(:widget_errors, widget_errors)
  end

  defp load_widget_safe(socket, widget_errors, widget_name, fetch_fn, assign_key)
       when is_atom(assign_key) do
    try do
      data = fetch_fn.()
      {assign(socket, assign_key, data), widget_errors}
    rescue
      e ->
        require Logger
        Logger.error("Failed to load #{widget_name}: #{Exception.message(e)}")

        {socket,
         Map.put(widget_errors, widget_name, "Failed to load data: #{Exception.message(e)}")}
    end
  end

  defp load_widget_safe(socket, widget_errors, widget_name, fetch_fn, assign_fn)
       when is_function(assign_fn) do
    try do
      data = fetch_fn.()
      assigns = assign_fn.(data)
      {Enum.reduce(assigns, socket, fn {key, val}, acc -> assign(acc, key, val) end), widget_errors}
    rescue
      e ->
        require Logger
        Logger.error("Failed to load #{widget_name}: #{Exception.message(e)}")

        {socket,
         Map.put(widget_errors, widget_name, "Failed to load data: #{Exception.message(e)}")}
    end
  end

  defp load_widget_data(socket, widget_name) do
    tenant_id = socket.assigns.current_scope.user.tenant_id
    time_period = socket.assigns.time_period
    date_range = Dashboard.calculate_date_range(time_period)

    widget_errors = socket.assigns.widget_errors

    {socket, widget_errors} =
      case widget_name do
        "inventory_summary" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            Dashboard.get_inventory_metrics(tenant_id)
          end, :inventory_metrics)

        "financial_metrics" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            Dashboard.get_financial_metrics(tenant_id, date_range)
          end, :financial_metrics)

        "stock_alerts" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            Dashboard.get_stock_alerts(tenant_id)
          end, :stock_alerts)

        "performance_comparison" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            Dashboard.get_performance_comparison(tenant_id, date_range)
          end, :performance_comparison)

        "stock_movement" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            Dashboard.get_stock_movement_data(tenant_id, date_range)
          end, :stock_movement_data)

        "top_products" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            Dashboard.get_top_products(tenant_id, date_range)
          end, :top_products)

        "recent_transactions" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            {Dashboard.get_recent_stock_ins(tenant_id, 10),
             Dashboard.get_recent_stock_outs(tenant_id, 10)}
          end, fn {stock_ins, stock_outs} ->
            [recent_stock_ins: stock_ins, recent_stock_outs: stock_outs]
          end)

        "farmer_activity" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            Dashboard.get_top_farmers(tenant_id, date_range)
          end, :top_farmers)

        "customer_activity" ->
          load_widget_safe(socket, widget_errors, widget_name, fn ->
            Dashboard.get_top_customers(tenant_id, date_range)
          end, :top_customers)

        _ ->
          {socket, widget_errors}
      end

    assign(socket, :widget_errors, widget_errors)
  end

  # Widget Components

  attr :metrics, :map, required: true

  defp inventory_summary_widget(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base md:text-lg font-semibold text-gray-900">Inventory Summary</h3>
        <div class="p-2 bg-blue-100 rounded-lg">
          <.icon name="hero-cube" class="size-5 md:size-6 text-blue-600" />
        </div>
      </div>

      <div class="space-y-3 md:space-y-4">
        <div>
          <p class="text-xs md:text-sm text-gray-500">Total Stock</p>
          <p class="text-xl md:text-2xl font-bold text-gray-900">
            {format_number(@metrics.total_stock)}
            <span class="text-xs md:text-sm font-normal text-gray-500">quintals</span>
          </p>
        </div>

        <div class="border-t border-gray-100 pt-3 md:pt-4">
          <div class="flex items-center justify-between gap-4">
            <div class="flex-1">
              <p class="text-xs md:text-sm text-gray-500">Products</p>
              <p class="text-lg md:text-xl font-semibold text-gray-900">{@metrics.product_count}</p>
            </div>
            <div class="text-right flex-1">
              <p class="text-xs md:text-sm text-gray-500">Total Value</p>
              <p class="text-lg md:text-xl font-semibold text-gray-900 truncate">
                ₹{format_number(@metrics.total_value)}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :metrics, :map, required: true
  attr :restricted, :boolean, default: false

  defp financial_metrics_widget(assigns) do
    assigns = assign(assigns, :margin_positive, assigns.metrics.gross_margin >= 0)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base md:text-lg font-semibold text-gray-900">Financial Metrics</h3>
        <div class="p-2 bg-green-100 rounded-lg">
          <.icon name="hero-currency-rupee" class="size-5 md:size-6 text-green-600" />
        </div>
      </div>

      <div class="space-y-3 md:space-y-4">
        <div class="grid grid-cols-2 gap-3 md:gap-4">
          <div>
            <p class="text-xs md:text-sm text-gray-500">Purchases</p>
            <p class="text-base md:text-lg font-semibold text-gray-900 truncate">
              ₹{format_number(@metrics.total_purchases)}
            </p>
            <p class="text-xs text-gray-400">{@metrics.stock_in_count} txns</p>
          </div>
          <div>
            <p class="text-xs md:text-sm text-gray-500">Sales</p>
            <p class="text-base md:text-lg font-semibold text-gray-900 truncate">
              ₹{format_number(@metrics.total_sales)}
            </p>
            <p class="text-xs text-gray-400">{@metrics.stock_out_count} txns</p>
          </div>
        </div>

        <div class="border-t border-gray-100 pt-3 md:pt-4">
          <p class="text-xs md:text-sm text-gray-500">Gross Margin</p>
          <p class={[
            "text-xl md:text-2xl font-bold truncate",
            @margin_positive && "text-green-600",
            !@margin_positive && "text-red-600"
          ]}>
            ₹{format_number(@metrics.gross_margin)}
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :alerts, :list, required: true

  defp stock_alerts_widget(assigns) do
    assigns =
      assigns
      |> assign(:alert_count, length(assigns.alerts))
      |> assign(:has_alerts, length(assigns.alerts) > 0)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-2">
          <h3 class="text-base md:text-lg font-semibold text-gray-900">Stock Alerts</h3>
          <%= if @has_alerts do %>
            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
              {@alert_count}
            </span>
          <% end %>
        </div>
        <div class="p-2 bg-yellow-100 rounded-lg">
          <.icon name="hero-exclamation-triangle" class="size-5 md:size-6 text-yellow-600" />
        </div>
      </div>

      <%= if @has_alerts do %>
        <div class="space-y-2 max-h-48 md:max-h-56 overflow-y-auto">
          <div
            :for={alert <- @alerts}
            class="flex items-center justify-between gap-2 p-2.5 md:p-3 bg-gray-50 rounded-lg"
          >
            <div class="flex-1 min-w-0">
              <p class="text-xs md:text-sm font-medium text-gray-900 truncate">
                {alert.product_name}
              </p>
              <p class="text-xs text-gray-500">{format_number(alert.current_stock)} quintals</p>
            </div>
            <span class={[
              "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0",
              alert.severity == :out_of_stock && "bg-red-100 text-red-800",
              alert.severity == :low_stock && "bg-yellow-100 text-yellow-800"
            ]}>
              {if alert.severity == :out_of_stock, do: "Out", else: "Low"}
            </span>
          </div>
        </div>
      <% else %>
        <div class="text-center py-6 md:py-8">
          <.icon name="hero-check-circle" class="size-10 md:size-12 text-green-500 mx-auto mb-2" />
          <p class="text-xs md:text-sm text-gray-500">All products are well stocked</p>
        </div>
      <% end %>
    </div>
    """
  end

  attr :comparison, :map, required: true

  defp performance_comparison_widget(assigns) do
    assigns =
      assigns
      |> assign(:stock_in_positive, assigns.comparison.stock_in_change >= 0)
      |> assign(:stock_out_positive, assigns.comparison.stock_out_change >= 0)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base md:text-lg font-semibold text-gray-900">Performance Comparison</h3>
        <div class="p-2 bg-purple-100 rounded-lg">
          <.icon name="hero-chart-bar-square" class="size-5 md:size-6 text-purple-600" />
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
        <div>
          <p class="text-xs md:text-sm text-gray-500 mb-2">Stock-In Volume</p>
          <div class="flex items-baseline gap-2">
            <p class="text-xl md:text-2xl font-bold text-gray-900">
              {format_number(@comparison.current_stock_in)}
            </p>
            <span class="text-xs md:text-sm text-gray-500">quintals</span>
          </div>
          <div class="flex items-center gap-1 mt-2 flex-wrap">
            <%= if @stock_in_positive do %>
              <.icon name="hero-arrow-trending-up" class="size-4 text-green-600 flex-shrink-0" />
              <span class="text-xs md:text-sm font-medium text-green-600">
                +{format_percentage(@comparison.stock_in_change)}%
              </span>
            <% else %>
              <.icon name="hero-arrow-trending-down" class="size-4 text-red-600 flex-shrink-0" />
              <span class="text-xs md:text-sm font-medium text-red-600">
                {format_percentage(@comparison.stock_in_change)}%
              </span>
            <% end %>
            <span class="text-xs text-gray-500">vs previous</span>
          </div>
        </div>

        <div>
          <p class="text-xs md:text-sm text-gray-500 mb-2">Stock-Out Volume</p>
          <div class="flex items-baseline gap-2">
            <p class="text-xl md:text-2xl font-bold text-gray-900">
              {format_number(@comparison.current_stock_out)}
            </p>
            <span class="text-xs md:text-sm text-gray-500">quintals</span>
          </div>
          <div class="flex items-center gap-1 mt-2 flex-wrap">
            <%= if @stock_out_positive do %>
              <.icon name="hero-arrow-trending-up" class="size-4 text-green-600 flex-shrink-0" />
              <span class="text-xs md:text-sm font-medium text-green-600">
                +{format_percentage(@comparison.stock_out_change)}%
              </span>
            <% else %>
              <.icon name="hero-arrow-trending-down" class="size-4 text-red-600 flex-shrink-0" />
              <span class="text-xs md:text-sm font-medium text-red-600">
                {format_percentage(@comparison.stock_out_change)}%
              </span>
            <% end %>
            <span class="text-xs text-gray-500">vs previous</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :data, :map, required: true

  defp stock_movement_chart_widget(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base md:text-lg font-semibold text-gray-900">Stock Movement Trends</h3>
        <div class="p-2 bg-indigo-100 rounded-lg">
          <.icon name="hero-chart-bar" class="size-5 md:size-6 text-indigo-600" />
        </div>
      </div>

      <div class="h-48 md:h-64 lg:h-72 flex items-center justify-center bg-gray-50 rounded-lg">
        <div class="text-center">
          <.icon name="hero-chart-bar" class="size-10 md:size-12 text-gray-400 mx-auto mb-2" />
          <p class="text-xs md:text-sm text-gray-500">Chart will be implemented with Chart.js</p>
          <p class="text-xs text-gray-400 mt-1">
            {length(@data.dates)} data points available
          </p>
        </div>
      </div>

      <div class="mt-4 flex items-center justify-center gap-4 md:gap-6 flex-wrap">
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 bg-green-500 rounded-full"></div>
          <span class="text-xs md:text-sm text-gray-600">Stock-In</span>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 bg-red-500 rounded-full"></div>
          <span class="text-xs md:text-sm text-gray-600">Stock-Out</span>
        </div>
      </div>
    </div>
    """
  end

  attr :products, :map, required: true

  defp top_products_widget(assigns) do
    assigns =
      assigns
      |> assign(:has_stock_in, length(assigns.products.stock_in) > 0)
      |> assign(:has_stock_out, length(assigns.products.stock_out) > 0)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base md:text-lg font-semibold text-gray-900">Top Products</h3>
        <div class="p-2 bg-orange-100 rounded-lg">
          <.icon name="hero-star" class="size-5 md:size-6 text-orange-600" />
        </div>
      </div>

      <div class="space-y-4">
        <div>
          <h4 class="text-xs md:text-sm font-medium text-gray-700 mb-3">Top Stock-In</h4>
          <%= if @has_stock_in do %>
            <div class="space-y-2 md:space-y-3">
              <div :for={product <- @products.stock_in} class="flex items-center gap-2 md:gap-3">
                <div class="flex-1 min-w-0">
                  <p class="text-xs md:text-sm font-medium text-gray-900 truncate">
                    {product.product_name}
                  </p>
                  <div class="flex items-center gap-2 mt-1">
                    <div class="flex-1 bg-gray-200 rounded-full h-2">
                      <div
                        class="bg-green-500 h-2 rounded-full"
                        style={"width: #{product.percentage}%"}
                      >
                      </div>
                    </div>
                    <span class="text-xs text-gray-500 w-10 md:w-12 text-right flex-shrink-0">
                      {product.percentage}%
                    </span>
                  </div>
                </div>
                <div class="text-right flex-shrink-0">
                  <p class="text-xs md:text-sm font-semibold text-gray-900">
                    {format_number(product.quantity)}
                  </p>
                  <p class="text-xs text-gray-500">quintals</p>
                </div>
              </div>
            </div>
          <% else %>
            <p class="text-xs md:text-sm text-gray-500 text-center py-4">No data available</p>
          <% end %>
        </div>

        <div class="border-t border-gray-100 pt-4">
          <h4 class="text-xs md:text-sm font-medium text-gray-700 mb-3">Top Stock-Out</h4>
          <%= if @has_stock_out do %>
            <div class="space-y-2 md:space-y-3">
              <div :for={product <- @products.stock_out} class="flex items-center gap-2 md:gap-3">
                <div class="flex-1 min-w-0">
                  <p class="text-xs md:text-sm font-medium text-gray-900 truncate">
                    {product.product_name}
                  </p>
                  <div class="flex items-center gap-2 mt-1">
                    <div class="flex-1 bg-gray-200 rounded-full h-2">
                      <div class="bg-red-500 h-2 rounded-full" style={"width: #{product.percentage}%"}>
                      </div>
                    </div>
                    <span class="text-xs text-gray-500 w-10 md:w-12 text-right flex-shrink-0">
                      {product.percentage}%
                    </span>
                  </div>
                </div>
                <div class="text-right flex-shrink-0">
                  <p class="text-xs md:text-sm font-semibold text-gray-900">
                    {format_number(product.quantity)}
                  </p>
                  <p class="text-xs text-gray-500">quintals</p>
                </div>
              </div>
            </div>
          <% else %>
            <p class="text-xs md:text-sm text-gray-500 text-center py-4">No data available</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :stock_ins, :list, required: true
  attr :stock_outs, :list, required: true
  attr :can_navigate, :boolean, default: true

  defp recent_transactions_widget(assigns) do
    assigns =
      assigns
      |> assign(:active_tab, "stock_in")
      |> assign(:has_stock_ins, length(assigns.stock_ins) > 0)
      |> assign(:has_stock_outs, length(assigns.stock_outs) > 0)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base md:text-lg font-semibold text-gray-900">Recent Transactions</h3>
        <div class="p-2 bg-teal-100 rounded-lg">
          <.icon name="hero-clock" class="size-5 md:size-6 text-teal-600" />
        </div>
      </div>

      <div class="space-y-3 md:space-y-4">
        <%!-- Tabs --%>
        <div class="flex border-b border-gray-200">
          <button
            type="button"
            phx-click={
              JS.add_class("border-blue-500 text-blue-600", to: "#tab-stock-in")
              |> JS.remove_class("border-transparent text-gray-500", to: "#tab-stock-in")
              |> JS.add_class("border-transparent text-gray-500", to: "#tab-stock-out")
              |> JS.remove_class("border-blue-500 text-blue-600", to: "#tab-stock-out")
              |> JS.show(to: "#content-stock-in")
              |> JS.hide(to: "#content-stock-out")
            }
            id="tab-stock-in"
            class="px-3 md:px-4 py-2 text-xs md:text-sm font-medium border-b-2 border-blue-500 text-blue-600 transition-colors"
          >
            Stock-In
          </button>
          <button
            type="button"
            phx-click={
              JS.add_class("border-blue-500 text-blue-600", to: "#tab-stock-out")
              |> JS.remove_class("border-transparent text-gray-500", to: "#tab-stock-out")
              |> JS.add_class("border-transparent text-gray-500", to: "#tab-stock-in")
              |> JS.remove_class("border-blue-500 text-blue-600", to: "#tab-stock-in")
              |> JS.show(to: "#content-stock-out")
              |> JS.hide(to: "#content-stock-in")
            }
            id="tab-stock-out"
            class="px-3 md:px-4 py-2 text-xs md:text-sm font-medium border-b-2 border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 transition-colors"
          >
            Stock-Out
          </button>
        </div>

        <%!-- Stock-In Content --%>
        <div id="content-stock-in">
          <%= if @has_stock_ins do %>
            <div class="space-y-2">
              <%= if @can_navigate do %>
                <.link
                  :for={stock_in <- @stock_ins}
                  navigate={~p"/stock-ins"}
                  class="block p-2.5 md:p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors min-h-[44px]"
                >
                  <div class="flex items-center justify-between gap-2">
                    <div class="flex-1 min-w-0">
                      <p class="text-xs md:text-sm font-medium text-gray-900 truncate">
                        {stock_in.farmer_name}
                      </p>
                      <p class="text-xs text-gray-500 truncate">{stock_in.product_name}</p>
                    </div>
                    <div class="text-right flex-shrink-0">
                      <p class="text-xs md:text-sm font-semibold text-gray-900">
                        {format_number(stock_in.total_quintals)} q
                      </p>
                      <p class="text-xs text-gray-500">{format_relative_time(stock_in.date)}</p>
                    </div>
                  </div>
                </.link>
              <% else %>
                <div
                  :for={stock_in <- @stock_ins}
                  class="block p-2.5 md:p-3 bg-gray-50 rounded-lg min-h-[44px]"
                >
                  <div class="flex items-center justify-between gap-2">
                    <div class="flex-1 min-w-0">
                      <p class="text-xs md:text-sm font-medium text-gray-900 truncate">
                        {stock_in.farmer_name}
                      </p>
                      <p class="text-xs text-gray-500 truncate">{stock_in.product_name}</p>
                    </div>
                    <div class="text-right flex-shrink-0">
                      <p class="text-xs md:text-sm font-semibold text-gray-900">
                        {format_number(stock_in.total_quintals)} q
                      </p>
                      <p class="text-xs text-gray-500">{format_relative_time(stock_in.date)}</p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="text-center py-6 md:py-8">
              <.icon name="hero-inbox" class="size-10 md:size-12 text-gray-400 mx-auto mb-2" />
              <p class="text-xs md:text-sm text-gray-500">No recent stock-in transactions</p>
            </div>
          <% end %>
        </div>

        <%!-- Stock-Out Content --%>
        <div id="content-stock-out" class="hidden">
          <%= if @has_stock_outs do %>
            <div class="space-y-2">
              <%= if @can_navigate do %>
                <.link
                  :for={stock_out <- @stock_outs}
                  navigate={~p"/stock-outs"}
                  class="block p-2.5 md:p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors min-h-[44px]"
                >
                  <div class="flex items-center justify-between gap-2">
                    <div class="flex-1 min-w-0">
                      <p class="text-xs md:text-sm font-medium text-gray-900 truncate">
                        {stock_out.customer_name}
                      </p>
                      <p class="text-xs text-gray-500 truncate">{stock_out.product_name}</p>
                    </div>
                    <div class="text-right flex-shrink-0">
                      <p class="text-xs md:text-sm font-semibold text-gray-900">
                        {format_number(stock_out.total_quintals)} q
                      </p>
                      <p class="text-xs text-gray-500">{format_relative_time(stock_out.date)}</p>
                    </div>
                  </div>
                </.link>
              <% else %>
                <div
                  :for={stock_out <- @stock_outs}
                  class="block p-2.5 md:p-3 bg-gray-50 rounded-lg min-h-[44px]"
                >
                  <div class="flex items-center justify-between gap-2">
                    <div class="flex-1 min-w-0">
                      <p class="text-xs md:text-sm font-medium text-gray-900 truncate">
                        {stock_out.customer_name}
                      </p>
                      <p class="text-xs text-gray-500 truncate">{stock_out.product_name}</p>
                    </div>
                    <div class="text-right flex-shrink-0">
                      <p class="text-xs md:text-sm font-semibold text-gray-900">
                        {format_number(stock_out.total_quintals)} q
                      </p>
                      <p class="text-xs text-gray-500">{format_relative_time(stock_out.date)}</p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <div class="text-center py-6 md:py-8">
              <.icon name="hero-inbox" class="size-10 md:size-12 text-gray-400 mx-auto mb-2" />
              <p class="text-xs md:text-sm text-gray-500">No recent stock-out transactions</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :farmers, :list, required: true
  attr :can_navigate, :boolean, default: true

  defp farmer_activity_widget(assigns) do
    assigns = assign(assigns, :has_farmers, length(assigns.farmers) > 0)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base md:text-lg font-semibold text-gray-900">Top Farmers</h3>
        <div class="p-2 bg-green-100 rounded-lg">
          <.icon name="hero-user-group" class="size-5 md:size-6 text-green-600" />
        </div>
      </div>

      <%= if @has_farmers do %>
        <%!-- Mobile Card Layout --%>
        <div class="md:hidden space-y-3">
          <div
            :for={farmer <- @farmers}
            class="p-3 bg-gray-50 rounded-lg border border-gray-200 hover:bg-gray-100 transition-colors"
          >
            <%= if @can_navigate do %>
              <.link navigate={~p"/stock-ins"} class="block">
                <div class="flex items-start justify-between mb-2">
                  <p class="text-sm font-semibold text-blue-600 hover:text-blue-800">
                    {farmer.farmer_name}
                  </p>
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    {farmer.transaction_count} txns
                  </span>
                </div>
                <div class="grid grid-cols-2 gap-2 text-xs">
                  <div>
                    <p class="text-gray-500">Quantity</p>
                    <p class="font-semibold text-gray-900">
                      {format_number(farmer.total_quantity)} q
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="text-gray-500">Amount</p>
                    <p class="font-semibold text-gray-900">₹{format_number(farmer.total_amount)}</p>
                  </div>
                </div>
              </.link>
            <% else %>
              <div>
                <div class="flex items-start justify-between mb-2">
                  <p class="text-sm font-semibold text-gray-900">{farmer.farmer_name}</p>
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    {farmer.transaction_count} txns
                  </span>
                </div>
                <div class="grid grid-cols-2 gap-2 text-xs">
                  <div>
                    <p class="text-gray-500">Quantity</p>
                    <p class="font-semibold text-gray-900">
                      {format_number(farmer.total_quantity)} q
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="text-gray-500">Amount</p>
                    <p class="font-semibold text-gray-900">₹{format_number(farmer.total_amount)}</p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        <%!-- Desktop Table Layout --%>
        <div class="hidden md:block overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead>
              <tr>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                  Farmer
                </th>
                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                  Quantity
                </th>
                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                  Amount
                </th>
                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Txns</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr :for={farmer <- @farmers} class="hover:bg-gray-50">
                <td class="px-3 py-3">
                  <%= if @can_navigate do %>
                    <.link
                      navigate={~p"/stock-ins"}
                      class="text-sm font-medium text-blue-600 hover:text-blue-800"
                    >
                      {farmer.farmer_name}
                    </.link>
                  <% else %>
                    <span class="text-sm font-medium text-gray-900">{farmer.farmer_name}</span>
                  <% end %>
                </td>
                <td class="px-3 py-3 text-right text-sm text-gray-900">
                  {format_number(farmer.total_quantity)}
                </td>
                <td class="px-3 py-3 text-right text-sm text-gray-900">
                  ₹{format_number(farmer.total_amount)}
                </td>
                <td class="px-3 py-3 text-right text-sm text-gray-500">{farmer.transaction_count}</td>
              </tr>
            </tbody>
          </table>
        </div>
      <% else %>
        <div class="text-center py-8">
          <.icon name="hero-user-group" class="size-10 md:size-12 text-gray-400 mx-auto mb-2" />
          <p class="text-xs md:text-sm text-gray-500">No farmer activity data</p>
        </div>
      <% end %>
    </div>
    """
  end

  attr :customers, :list, required: true
  attr :can_navigate, :boolean, default: true

  defp customer_activity_widget(assigns) do
    assigns = assign(assigns, :has_customers, length(assigns.customers) > 0)

    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 md:p-6 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base md:text-lg font-semibold text-gray-900">Top Customers</h3>
        <div class="p-2 bg-blue-100 rounded-lg">
          <.icon name="hero-user-group" class="size-5 md:size-6 text-blue-600" />
        </div>
      </div>

      <%= if @has_customers do %>
        <%!-- Mobile Card Layout --%>
        <div class="md:hidden space-y-3">
          <div
            :for={customer <- @customers}
            class="p-3 bg-gray-50 rounded-lg border border-gray-200 hover:bg-gray-100 transition-colors"
          >
            <%= if @can_navigate do %>
              <.link navigate={~p"/stock-outs"} class="block">
                <div class="flex items-start justify-between mb-2">
                  <p class="text-sm font-semibold text-blue-600 hover:text-blue-800">
                    {customer.customer_name}
                  </p>
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    {customer.transaction_count} txns
                  </span>
                </div>
                <div class="grid grid-cols-2 gap-2 text-xs">
                  <div>
                    <p class="text-gray-500">Quantity</p>
                    <p class="font-semibold text-gray-900">
                      {format_number(customer.total_quantity)} q
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="text-gray-500">Amount</p>
                    <p class="font-semibold text-gray-900">
                      ₹{format_number(customer.total_amount)}
                    </p>
                  </div>
                </div>
              </.link>
            <% else %>
              <div>
                <div class="flex items-start justify-between mb-2">
                  <p class="text-sm font-semibold text-gray-900">{customer.customer_name}</p>
                  <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    {customer.transaction_count} txns
                  </span>
                </div>
                <div class="grid grid-cols-2 gap-2 text-xs">
                  <div>
                    <p class="text-gray-500">Quantity</p>
                    <p class="font-semibold text-gray-900">
                      {format_number(customer.total_quantity)} q
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="text-gray-500">Amount</p>
                    <p class="font-semibold text-gray-900">
                      ₹{format_number(customer.total_amount)}
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        <%!-- Desktop Table Layout --%>
        <div class="hidden md:block overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead>
              <tr>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
                  Customer
                </th>
                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                  Quantity
                </th>
                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">
                  Amount
                </th>
                <th class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase">Txns</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr :for={customer <- @customers} class="hover:bg-gray-50">
                <td class="px-3 py-3">
                  <%= if @can_navigate do %>
                    <.link
                      navigate={~p"/stock-outs"}
                      class="text-sm font-medium text-blue-600 hover:text-blue-800"
                    >
                      {customer.customer_name}
                    </.link>
                  <% else %>
                    <span class="text-sm font-medium text-gray-900">{customer.customer_name}</span>
                  <% end %>
                </td>
                <td class="px-3 py-3 text-right text-sm text-gray-900">
                  {format_number(customer.total_quantity)}
                </td>
                <td class="px-3 py-3 text-right text-sm text-gray-900">
                  ₹{format_number(customer.total_amount)}
                </td>
                <td class="px-3 py-3 text-right text-sm text-gray-500">
                  {customer.transaction_count}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% else %>
        <div class="text-center py-8">
          <.icon name="hero-user-group" class="size-10 md:size-12 text-gray-400 mx-auto mb-2" />
          <p class="text-xs md:text-sm text-gray-500">No customer activity data</p>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper Functions

  defp format_number(nil), do: "0"

  defp format_number(number) when is_integer(number) or is_float(number) do
    number
    |> Decimal.new()
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_with_commas()
  end

  defp format_number(number) when is_binary(number) do
    case Decimal.parse(number) do
      {decimal, _} ->
        decimal
        |> Decimal.round(2)
        |> Decimal.to_string()
        |> format_with_commas()

      :error ->
        number
    end
  end

  defp format_number(%Decimal{} = number) do
    number
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_with_commas()
  end

  defp format_with_commas(number_string) do
    [integer_part, decimal_part] =
      case String.split(number_string, ".") do
        [int] -> [int, nil]
        [int, dec] -> [int, dec]
      end

    formatted_integer =
      integer_part
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.reverse/1)
      |> Enum.reverse()
      |> Enum.map(&Enum.join/1)
      |> Enum.join(",")

    if decimal_part do
      "#{formatted_integer}.#{decimal_part}"
    else
      formatted_integer
    end
  end

  defp format_percentage(number) when is_float(number) or is_integer(number) do
    number
    |> abs()
    |> :erlang.float_to_binary(decimals: 1)
  end

  defp format_percentage(%Decimal{} = number) do
    number
    |> Decimal.abs()
    |> Decimal.round(1)
    |> Decimal.to_string()
  end

  defp format_relative_time(date) when is_struct(date, Date) do
    today = Date.utc_today()
    days_diff = Date.diff(today, date)

    cond do
      days_diff == 0 -> "Today"
      days_diff == 1 -> "Yesterday"
      days_diff < 7 -> "#{days_diff} days ago"
      days_diff < 30 -> "#{div(days_diff, 7)} weeks ago"
      days_diff < 365 -> "#{div(days_diff, 30)} months ago"
      true -> "#{div(days_diff, 365)} years ago"
    end
  end

  defp format_relative_time(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.to_date()
    |> format_relative_time()
  end

  defp format_relative_time(_), do: "Unknown"

  # Role-based Permission Helpers

  defp can_view_financial?(role) when role in [:company_admin, :operator], do: true
  defp can_view_financial?(_role), do: false

  defp can_perform_actions?(role) when role in [:company_admin, :operator], do: true
  defp can_perform_actions?(_role), do: false

  defp widget_visible?(widget_name, role) do
    case widget_name do
      :financial_metrics -> can_view_financial?(role)
      :farmer_activity -> can_view_financial?(role)
      :customer_activity -> can_view_financial?(role)
      _ -> true
    end
  end

  # Widget Ordering Helpers

  @default_widget_order [
    "inventory_summary",
    "financial_metrics",
    "stock_alerts",
    "performance_comparison",
    "stock_movement",
    "top_products",
    "recent_transactions",
    "farmer_activity",
    "customer_activity"
  ]

  defp get_ordered_widgets(assigns) do
    widget_order =
      if assigns.widget_order == [] do
        @default_widget_order
      else
        assigns.widget_order
      end

    # Filter out widgets that are hidden or not visible to the user's role
    widget_order
    |> Enum.filter(fn widget_id ->
      widget_atom = String.to_atom(widget_id)
      widget_id not in assigns.hidden_widgets and widget_visible?(widget_atom, assigns.user_role)
    end)
  end
end
