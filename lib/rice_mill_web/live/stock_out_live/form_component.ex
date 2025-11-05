defmodule RiceMillWeb.StockOutLive.FormComponent do
  use RiceMillWeb, :live_component

  alias RiceMill.Inventory

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <.header>
        {@title}
        <:subtitle>Record a product sale or outgoing stock.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="stock-out-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.input
            field={@form[:product_id]}
            type="select"
            label="Product"
            options={Enum.map(@products, &{&1.name, &1.id})}
            prompt="Select a product"
            required
          />
          <.input field={@form[:date]} type="date" label="Date" required />
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.input field={@form[:customer_name]} type="text" label="Customer Name" required />
          <.input field={@form[:customer_contact]} type="text" label="Customer Contact" required />
        </div>

        <.input field={@form[:vehicle_number]} type="text" label="Vehicle Number" />

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <.input
            field={@form[:num_of_bags]}
            type="number"
            label="Number of Bags"
            min="1"
            required
          />
          <.input
            field={@form[:net_weight_per_bag_kg]}
            type="number"
            label="Net Weight per Bag (kg)"
            step="0.01"
            min="0"
            required
          />
          <.input
            field={@form[:price_per_quintal]}
            type="number"
            label="Price per Quintal (₹)"
            step="0.01"
            min="0"
            required
          />
        </div>

        <div
          :if={@calculated_totals}
          class="bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 rounded-xl p-5 shadow-sm"
        >
          <h3 class="text-base font-semibold text-green-900 mb-3 flex items-center">
            <.icon name="hero-calculator" class="size-5 mr-2" /> Calculated Totals
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="bg-white rounded-lg p-3 shadow-sm">
              <span class="text-xs font-medium text-green-600 uppercase tracking-wide">
                Total Quintals
              </span>
              <p class="mt-1 text-2xl font-bold text-gray-900">
                {@calculated_totals.total_quintals}
              </p>
            </div>
            <div class="bg-white rounded-lg p-3 shadow-sm">
              <span class="text-xs font-medium text-green-600 uppercase tracking-wide">
                Total Price
              </span>
              <p class="mt-1 text-2xl font-bold text-gray-900">
                ₹{@calculated_totals.total_price}
              </p>
            </div>
          </div>
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-3 pt-4 border-t border-gray-200">
          <.button
            type="button"
            phx-click={JS.navigate(@navigate)}
            variant="secondary"
          >
            Cancel
          </.button>
          <.button type="submit" phx-disable-with="Saving..." variant="primary">
            Save Stock-Out
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{stock_out: stock_out} = assigns, socket) do
    changeset = Inventory.change_stock_out(stock_out)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:calculated_totals, nil)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"stock_out" => stock_out_params}, socket) do
    # Auto-fill price when product is selected
    stock_out_params = maybe_autofill_price(stock_out_params, socket.assigns.products)

    changeset =
      socket.assigns.stock_out
      |> Inventory.change_stock_out(stock_out_params)
      |> Map.put(:action, :validate)

    # Calculate totals for display
    calculated_totals = extract_calculated_totals(changeset)

    {:noreply,
     socket
     |> assign(:calculated_totals, calculated_totals)
     |> assign_form(changeset)}
  end

  def handle_event("save", %{"stock_out" => stock_out_params}, socket) do
    save_stock_out(socket, socket.assigns.action, stock_out_params)
  end

  defp save_stock_out(socket, :new, stock_out_params) do
    tenant_id = socket.assigns.current_scope.user.tenant_id

    case Inventory.create_stock_out(tenant_id, stock_out_params) do
      {:ok, stock_out} ->
        # Preload product for display
        stock_out = RiceMill.Repo.preload(stock_out, :product)
        notify_parent({:saved, stock_out})

        {:noreply,
         socket
         |> put_flash(:info, "Stock-out entry created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp maybe_autofill_price(params, products) do
    product_id = params["product_id"]
    current_price = params["price_per_quintal"]

    # Only autofill if product is selected and price is empty or zero
    if product_id && product_id != "" && (current_price == "" || current_price == nil) do
      case Enum.find(products, &(&1.id == product_id)) do
        nil ->
          params

        product ->
          Map.put(params, "price_per_quintal", Decimal.to_string(product.price_per_quintal))
      end
    else
      params
    end
  end

  defp extract_calculated_totals(changeset) do
    total_quintals = Ecto.Changeset.get_field(changeset, :total_quintals)
    total_price = Ecto.Changeset.get_field(changeset, :total_price)

    if total_quintals && total_price do
      %{
        total_quintals: :erlang.float_to_binary(Decimal.to_float(total_quintals), decimals: 3),
        total_price: :erlang.float_to_binary(Decimal.to_float(total_price), decimals: 2)
      }
    else
      nil
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
