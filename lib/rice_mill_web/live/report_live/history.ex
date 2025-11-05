defmodule RiceMillWeb.ReportLive.History do
  use RiceMillWeb, :live_view

  alias RiceMill.Reports

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    socket =
      socket
      |> assign(:page_title, "Transaction History")
      |> assign(:filters, %{date_from: nil, date_to: nil, farmer_name: ""})
      |> load_transactions(tenant_id, %{})

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    # Parse date strings to Date structs
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

  defp load_transactions(socket, tenant_id, filters) do
    transactions = Reports.stock_in_history(tenant_id, filters)
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
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Transaction History</h1>
          <p class="mt-2 text-sm text-gray-700">
            View and filter all stock-in transactions
          </p>
        </div>
      </div>

      <div class="mt-6 bg-white shadow rounded-lg p-6">
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
                Farmer Name
              </label>
              <input
                type="text"
                name="filters[farmer_name]"
                id="farmer_name"
                value={@filters.farmer_name}
                placeholder="Search by farmer name"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              />
            </div>
          </div>

          <div class="mt-4 flex justify-end gap-3">
            <button
              type="button"
              phx-click="clear_filters"
              class="inline-flex items-center justify-center rounded-md bg-gray-200 px-4 py-2 text-sm font-semibold text-gray-700 shadow-sm hover:bg-gray-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-400 transition-colors"
            >
              Clear Filters
            </button>
          </div>
        </form>
      </div>

      <div class="mt-8 flow-root">
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
                      Date
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Product
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Farmer Name
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Contact
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Vehicle
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Quantity (Quintals)
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Total Price
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <tr
                    :for={transaction <- @transactions}
                    class="hover:bg-gray-50 transition-colors"
                  >
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm text-gray-900 sm:pl-6">
                      {Calendar.strftime(transaction.date, "%b %d, %Y")}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                      {transaction.product.name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
                      {transaction.farmer_name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {transaction.farmer_contact}
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
                    <td colspan="7" class="py-8 text-center text-sm text-gray-500">
                      No transactions found. Try adjusting your filters or add stock-in entries.
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
