defmodule RiceMillWeb.ProductLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Inventory
  alias RiceMill.Inventory.Product

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id
    {:ok, stream(socket, :products, Inventory.list_products(tenant_id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    socket
    |> assign(:page_title, "Edit Product")
    |> assign(:product, Inventory.get_product!(tenant_id, id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Product")
    |> assign(:product, %Product{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Products")
    |> assign(:product, nil)
  end

  @impl true
  def handle_info({RiceMillWeb.ProductLive.FormComponent, {:saved, product}}, socket) do
    {:noreply, stream_insert(socket, :products, product)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tenant_id = socket.assigns.current_scope.user.tenant_id
    product = Inventory.get_product!(tenant_id, id)
    {:ok, _} = Inventory.delete_product(product)

    {:noreply, stream_delete(socket, :products, product)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Products</h1>
          <p class="mt-2 text-sm text-gray-700">
            Manage your paddy products and pricing
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
          <.link
            navigate={~p"/products/new"}
            class="inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600 transition-colors"
          >
            Add Product
          </.link>
        </div>
      </div>

      <div :if={@live_action in [:new, :edit]} class="mt-8">
        <div class="bg-white shadow rounded-lg p-6">
          <.live_component
            module={RiceMillWeb.ProductLive.FormComponent}
            id={@product.id || :new}
            title={@page_title}
            action={@live_action}
            product={@product}
            current_scope={@current_scope}
            navigate={~p"/products"}
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
                      Name
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      SKU
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Category
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Unit
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Price/Quintal
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody id="products" phx-update="stream" class="divide-y divide-gray-200 bg-white">
                  <tr
                    :for={{id, product} <- @streams.products}
                    id={id}
                    class="hover:bg-gray-50 transition-colors"
                  >
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                      {product.name}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {product.sku}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {product.category}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      {product.unit}
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      ₹{:erlang.float_to_binary(Decimal.to_float(product.price_per_quintal),
                        decimals: 2
                      )}
                    </td>
                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                      <.link
                        navigate={~p"/products/#{product}/edit"}
                        class="text-blue-600 hover:text-blue-900 mr-4 transition-colors"
                      >
                        Edit
                      </.link>
                      <.link
                        phx-click={JS.push("delete", value: %{id: product.id})}
                        data-confirm="Are you sure?"
                        class="text-red-600 hover:text-red-900 transition-colors"
                      >
                        Delete
                      </.link>
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
