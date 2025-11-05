defmodule RiceMillWeb.Admin.TenantLive.FormComponent do
  use RiceMillWeb, :live_component

  alias RiceMill.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">{@title}</h2>

      <.form
        :let={f}
        for={@changeset}
        id="tenant-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input
            field={f[:name]}
            type="text"
            label="Name"
          />

          <div>
            <.input
              field={f[:slug]}
              type="text"
              label="Slug"
            />
            <p class="mt-1 text-sm text-gray-500">
              URL-friendly identifier (lowercase, hyphens only)
            </p>
          </div>

          <.input
            field={f[:contact_email]}
            type="email"
            label="Contact Email"
          />

          <.input
            field={f[:contact_phone]}
            type="text"
            label="Contact Phone"
          />

          <.input
            field={f[:active]}
            type="checkbox"
            label="Tenant is active"
          />

          <%= if @action == :new do %>
            <div class="border-t pt-4">
              <h3 class="text-md font-medium text-gray-900 mb-3">Admin User Details</h3>

              <div class="space-y-4">
                <.input
                  field={f[:admin_email]}
                  type="email"
                  label="Admin Email"
                />

                <.input
                  field={f[:admin_name]}
                  type="text"
                  label="Admin Name"
                />

                <div>
                  <.input
                    field={f[:admin_password]}
                    type="password"
                    label="Admin Password"
                    required
                    minlength="12"
                  />
                  <p class="mt-1 text-sm text-gray-500">
                    Password must be at least 12 characters
                  </p>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <div class="mt-6 flex justify-end space-x-3">
          <.link
            patch={@patch}
            class="inline-flex justify-center py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Cancel
          </.link>
          <button
            type="submit"
            class="inline-flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Save
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{tenant: tenant} = assigns, socket) do
    changeset = Accounts.change_tenant(tenant)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"tenant" => tenant_params}, socket) do
    changeset =
      socket.assigns.tenant
      |> Accounts.change_tenant(tenant_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"tenant" => tenant_params}, socket) do
    save_tenant(socket, socket.assigns.action, tenant_params)
  end

  defp save_tenant(socket, :edit, tenant_params) do
    case Accounts.update_tenant(
           socket.assigns.tenant,
           tenant_params,
           socket.assigns.current_scope.user
         ) do
      {:ok, _tenant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tenant updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_tenant(socket, :new, tenant_params) do
    admin_email = tenant_params["admin_email"]
    admin_name = tenant_params["admin_name"]
    admin_password = tenant_params["admin_password"]

    # Clean up tenant params
    tenant_params =
      tenant_params
      |> Map.drop(["admin_email", "admin_name", "admin_password"])

    case Accounts.create_tenant_with_admin(tenant_params, admin_email, admin_name, admin_password) do
      {:ok, %{tenant: _tenant, admin_user: _admin_user}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tenant created successfully with admin user")
         |> push_patch(to: socket.assigns.patch)}

      {:error, :tenant_creation_failed, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
