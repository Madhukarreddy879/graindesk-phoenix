defmodule RiceMillWeb.ReportLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Reports

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    socket =
      socket
      |> assign(:page_title, "Reports")
      |> assign(:active_tab, :stock_levels)
      |> assign(:filters, %{date_from: nil, date_to: nil, farmer_name: ""})
      |> load_stock_levels(tenant_id)
      |> load_transactions(tenant_id, %{})

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = String.to_existing_atom(params["tab"] || "stock_levels")
    {:noreply, assign(socket, :active_tab, tab)}
  rescue
    ArgumentError -> {:noreply, assign(socket, :active_tab, :stock_levels)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/reports?#{[tab: tab]}")}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    parsed_filters = %{
      date_from: parse_date(filters["date_from"]),
      date_to: parse_date(filters["date_to"]),
      farmer_name: filters["farmer_name"]
    }

    socket =
      socket
      |> assign(:filters, parsed_filters)
      |> load_transactions(tenant_id, parsed_filters)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    socket =
      socket
      |> assign(:filters, %{date_from: nil, date_to: nil, farmer_name: ""})
      |> load_transactions(tenant_id, %{})

    {:noreply, socket}
  end

  defp load_stock_levels(socket, tenant_id) do
    stock_levels = Reports.current_stock_levels(tenant_id)
    assign(socket, :stock_levels, stock_levels)
  end

  defp load_transactions(socket, tenant_id, filters) do
    transactions = Reports.transaction_history(tenant_id, filters)
    assign(socket, :transactions, transactions)
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center sm:justify-between">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Reports</h1>
          <p class="mt-2 text-sm text-gray-700">
            View inventory levels and transaction history
          </p>
        </div>
      </div>
      
    <!-- Tabs -->
      <div class="mt-6">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex space-x-8" aria-label="Tabs">
            <button
              phx-click="switch_tab"
              phx-value-tab="stock_levels"
              class={[
                "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium transition-colors",
                if(@active_tab == :stock_levels,
                  do: "border-blue-500 text-blue-600",
                  else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                )
              ]}
            >
              Stock Levels
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="history"
              class={[
                "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium transition-colors",
                if(@active_tab == :history,
                  do: "border-blue-500 text-blue-600",
                  else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                )
              ]}
            >
              Transaction History
            </button>
          </nav>
        </div>
      </div>
      
    <!-- Tab Content -->
      <div class="mt-6">
        <div :if={@active_tab == :stock_levels}>
          <.stock_levels_tab stock_levels={@stock_levels} />
        </div>

        <div :if={@active_tab == :history}>
          <.history_tab transactions={@transactions} filters={@filters} />
        </div>
      </div>
    </div>
    """
  end

  defp stock_levels_tab(assigns) do
    ~H"""
    <div class="flow-root">
      <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
          <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 rounded-lg">
            <table class="min-w-full divide-y divide-gray-300">
              <thead class="bg-gray-50">
                <tr>
                  <th
                    scope="col"
                    class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                  >
                    Product Name
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    SKU
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                    Stock In (Q)
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                    Stock Out (Q)
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                    Available (Q)
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white">
                <tr :for={stock <- @stock_levels} class="hover:bg-gray-50 transition-colors">
                  <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                    {stock.name}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    {stock.sku}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-blue-600 text-right font-medium">
                    {:erlang.float_to_binary(Decimal.to_float(stock.total_in), decimals: 3)}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-red-600 text-right font-medium">
                    {:erlang.float_to_binary(Decimal.to_float(stock.total_out), decimals: 3)}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-bold">
                    {:erlang.float_to_binary(Decimal.to_float(stock.available_stock), decimals: 3)}
                  </td>
                </tr>
                <tr :if={Enum.empty?(@stock_levels)}>
                  <td colspan="5" class="py-8 text-center text-sm text-gray-500">
                    No products found. Add products to see stock levels.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp history_tab(assigns) do
    ~H"""
    <div>
      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <form phx-change="filter" phx-submit="filter">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-3">
            <div>
              <label for="date_from" class="block text-sm font-medium text-gray-700">
                From Date
              </label>
              <input
                type="date"
                name="filters[date_from]"
                id="date_from"
                value={@filters.date_from && Date.to_iso8601(@filters.date_from)}
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label for="date_to" class="block text-sm font-medium text-gray-700">
                To Date
              </label>
              <input
                type="date"
                name="filters[date_to]"
                id="date_to"
                value={@filters.date_to && Date.to_iso8601(@filters.date_to)}
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>

            <div>
              <label for="farmer_name" class="block text-sm font-medium text-gray-700">
                Party Name
              </label>
              <input
                type="text"
                name="filters[farmer_name]"
                id="farmer_name"
                value={@filters.farmer_name}
                placeholder="Search by farmer or customer name"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>
          </div>

          <div class="mt-4 flex justify-end gap-3">
            <button
              type="button"
              phx-click="clear_filters"
              class="inline-flex items-center justify-center rounded-md bg-gray-200 px-4 py-2 text-sm font-semibold text-gray-700 shadow-sm hover:bg-gray-300 transition-colors"
            >
              Clear Filters
            </button>
          </div>
        </form>
      </div>

      <div class="flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                    >
                      Type
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Date
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Product
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Party Name
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Contact
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Vehicle
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Quantity (Q)
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Total Price
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <tr :for={transaction <- @transactions} class="hover:bg-gray-50 transition-colors">
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6">
                      <span class={[
                        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
                        if(transaction.type == :in,
                          do: "bg-blue-100 text-blue-800",
                          else: "bg-green-100 text-green-800"
                        )
                      ]}>
                        {if transaction.type == :in, do: "IN", else: "OUT"}
                      </span>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                      {Calendar.strftime(transaction.date, "%b %d, %Y")}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                      {transaction.product.name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                      {transaction.party_name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {transaction.party_contact}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {transaction.vehicle_number}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                      {:erlang.float_to_binary(Decimal.to_float(transaction.total_quintals),
                        decimals: 3
                      )}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                      ₹{:erlang.float_to_binary(Decimal.to_float(transaction.total_price),
                        decimals: 2
                      )}
                    </td>
                  </tr>
                  <tr :if={Enum.empty?(@transactions)}>
                    <td colspan="8" class="py-8 text-center text-sm text-gray-500">
                      No transactions found. Try adjusting your filters or add stock-in/stock-out entries.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
