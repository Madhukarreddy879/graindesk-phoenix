defmodule RiceMillWeb.ProductLive.FormComponent do
  use RiceMillWeb, :live_component

  alias RiceMill.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <.header>
        {@title}
        <:subtitle>Use this form to manage product records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="product-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" required />
        <.input field={@form[:sku]} type="text" label="SKU Code" required />

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.input
            field={@form[:category]}
            type="text"
            label="Category"
            readonly={@action == :edit}
          />
          <.input field={@form[:unit]} type="text" label="Unit" />
        </div>

        <.input
          field={@form[:price_per_quintal]}
          type="number"
          label="Price per Quintal (₹)"
          step="0.01"
          min="0"
          required
        />

        <div class="mt-6 flex items-center justify-end gap-x-3 pt-4 border-t border-gray-200">
          <.button
            type="button"
            phx-click={JS.navigate(@navigate)}
            variant="secondary"
          >
            Cancel
          </.button>
          <.button
            type="submit"
            phx-disable-with="Saving..."
            variant="primary"
          >
            Save Product
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{product: product} = assigns, socket) do
    # Set default values for new products
    product =
      if assigns.action == :new do
        %{product | category: "Paddy", unit: "quintal"}
      else
        product
      end

    changeset = Inventory.change_product(product)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"product" => product_params}, socket) do
    # For new products, we need to include tenant_id in validation
    product_params =
      if socket.assigns.action == :new do
        tenant_id = socket.assigns.current_scope.user.tenant_id
        Map.put(product_params, "tenant_id", tenant_id)
      else
        product_params
      end

    changeset =
      socket.assigns.product
      |> Inventory.change_product(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"product" => product_params}, socket) do
    save_product(socket, socket.assigns.action, product_params)
  end

  defp save_product(socket, :edit, product_params) do
    case Inventory.update_product(socket.assigns.product, product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        {:noreply,
         socket
         |> put_flash(:info, "Product updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_product(socket, :new, product_params) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    case Inventory.create_product(tenant_id, product_params) do
      {:ok, product} ->
        notify_parent({:saved, product})

        {:noreply,
         socket
         |> put_flash(:info, "Product created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
