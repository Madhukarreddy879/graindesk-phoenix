defmodule RiceMillWeb.StockInLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Inventory
  alias RiceMill.Inventory.StockIn

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id
    {:ok, stream(socket, :stock_ins, Inventory.list_stock_ins(tenant_id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    socket
    |> assign(:page_title, "New Stock-In Entry")
    |> assign(:stock_in, %StockIn{})
    |> assign(:products, Inventory.list_products(tenant_id))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Stock-In Entries")
    |> assign(:stock_in, nil)
  end

  @impl true
  def handle_info({RiceMillWeb.StockInLive.FormComponent, {:saved, stock_in}}, socket) do
    {:noreply, stream_insert(socket, :stock_ins, stock_in, at: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Stock-In Entries</h1>
          <p class="mt-2 text-sm text-gray-700">
            Record paddy purchases from farmers
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <.link
            navigate={~p"/stock-ins/new"}
            class="inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600 transition-colors"
          >
            Add Stock-In
          </.link>
        </div>
      </div>

      <div :if={@live_action == :new} class="mt-8">
        <div class="bg-white shadow rounded-lg p-6">
          <.live_component
            module={RiceMillWeb.StockInLive.FormComponent}
            id={:new}
            title={@page_title}
            action={@live_action}
            stock_in={@stock_in}
            products={@products}
            current_scope={@current_scope}
            navigate={~p"/stock-ins"}
          />
        </div>
      </div>

      <div :if={@live_action == :index} class="mt-8 flow-root">
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
                      Farmer
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
                      Total Price (₹)
                    </th>
                  </tr>
                </thead>
                <tbody id="stock_ins" phx-update="stream" class="divide-y divide-gray-200 bg-white">
                  <tr
                    :for={{id, stock_in} <- @streams.stock_ins}
                    id={id}
                    class="hover:bg-gray-50 transition-colors"
                  >
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                      {Calendar.strftime(stock_in.date, "%d %b %Y")}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {stock_in.product.name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {stock_in.farmer_name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {stock_in.farmer_contact}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {stock_in.vehicle_number}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 text-right">
                      {:erlang.float_to_binary(Decimal.to_float(stock_in.total_quintals), decimals: 3)}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 text-right">
                      ₹{:erlang.float_to_binary(Decimal.to_float(stock_in.total_price), decimals: 2)}
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
