defmodule RiceMillWeb.ReportLive.StockLevels do
  use RiceMillWeb, :live_view

  alias RiceMill.Reports

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id
    stock_levels = Reports.current_stock_levels(tenant_id)

    {:ok, assign(socket, stock_levels: stock_levels, page_title: "Stock Levels Report")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Stock Levels Report</h1>
          <p class="mt-2 text-sm text-gray-700">
            Current inventory levels for all products
          </p>
        </div>
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
                      Product Name
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      SKU
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-right text-sm font-semibold text-gray-900">
                      Total Stock (Quintals)
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <tr
                    :for={stock <- @stock_levels}
                    class="hover:bg-gray-50 transition-colors"
                  >
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                      {stock.name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {stock.sku}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900 text-right font-medium">
                      {:erlang.float_to_binary(Decimal.to_float(stock.total_stock), decimals: 3)}
                    </td>
                  </tr>
                  <tr :if={Enum.empty?(@stock_levels)}>
                    <td colspan="3" class="py-8 text-center text-sm text-gray-500">
                      No products found. Add products to see stock levels.
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
