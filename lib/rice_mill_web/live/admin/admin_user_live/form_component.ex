defmodule RiceMillWeb.Admin.AdminUserLive.FormComponent do
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
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <div>
            <.input
              field={f[:email]}
              type="email"
              label="Email"
              required
            />
          </div>

          <div>
            <.input
              field={f[:name]}
              type="text"
              label="Name"
            />
          </div>

          <div>
            <.input
              field={f[:contact_phone]}
              type="text"
              label="Contact Phone"
            />
          </div>

          <div>
            <.input
              field={f[:role]}
              type="select"
              label="Role"
              options={[
                {"Super Admin", "super_admin"},
                {"Company Admin", "company_admin"},
                {"Operator", "operator"},
                {"Viewer", "viewer"}
              ]}
              required
            />
          </div>

          <div>
            <.input
              field={f[:status]}
              type="select"
              label="Status"
              options={[
                {"Active", "active"},
                {"Inactive", "inactive"}
              ]}
              required
            />
          </div>

          <div>
            <.input
              field={f[:tenant_id]}
              type="select"
              label="Tenant"
              options={Enum.map(@tenants, &{&1.name, &1.id})}
              prompt="Select a tenant"
              required
            />
          </div>

          <%= if @action == :new do %>
            <div>
              <.input
                field={f[:password]}
                type="password"
                label="Password"
                required
              />
            </div>

            <div>
              <.input
                field={f[:password_confirmation]}
                type="password"
                label="Password Confirmation"
                required
              />
            </div>
          <% end %>
        </div>

        <div class="mt-6 flex items-center justify-end space-x-3">
          <.link
            patch={@navigate}
            class="inline-flex justify-center py-2 px-4 border border-gray-300 rounded-md shadow-sm bg-white text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Cancel
          </.link>
          <.button
            phx-disable-with="Saving..."
            class="inline-flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Save User
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset = Accounts.change_user(user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:tenants, Accounts.list_tenants())}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.user, user_params, socket.assigns.current_scope.user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.create_user(user_params, socket.assigns.current_scope.user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
