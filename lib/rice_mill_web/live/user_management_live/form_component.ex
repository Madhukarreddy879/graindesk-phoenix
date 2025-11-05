defmodule RiceMillWeb.UserManagementLive.FormComponent do
  use RiceMillWeb, :live_component

  alias RiceMill.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-medium text-gray-900 mb-4">{@title}</h2>

      <.form
        for={@form}
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <div>
            <.input field={@form[:email]} type="email" label="Email" required />
          </div>

          <div>
            <.input field={@form[:name]} type="text" label="Name" />
          </div>

          <div>
            <.input field={@form[:contact_phone]} type="text" label="Contact Phone" />
          </div>

          <div>
            <.input
              field={@form[:role]}
              type="select"
              label="Role"
              options={[
                {"Operator - Can manage inventory", :operator},
                {"Viewer - Read-only access", :viewer}
              ]}
              required
            />
            <p class="mt-1 text-sm text-gray-500">
              Operators can create and edit products and stock-in entries. Viewers can only view reports.
            </p>
          </div>

          <%= if @action == :new do %>
            <div>
              <.input field={@form[:password]} type="password" label="Password" required />
              <p class="mt-1 text-sm text-gray-500">
                Minimum 12 characters required.
              </p>
            </div>
          <% end %>

          <div class="flex justify-end space-x-3 pt-4">
            <.button
              type="button"
              phx-click={JS.patch(@navigate)}
              class="inline-flex justify-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
              Cancel
            </.button>
            <.button
              type="submit"
              phx-disable-with="Saving..."
              class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
              Save
            </.button>
          </div>
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
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(
           socket.assigns.user,
           user_params,
           socket.assigns.current_scope
         ) do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, :unauthorized_role} ->
        {:noreply,
         socket
         |> put_flash(:error, "You cannot assign super_admin or company_admin roles")
         |> assign_form(Accounts.change_user(socket.assigns.user, user_params))}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have permission to update this user")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    # Add tenant_id from current user
    current_user = socket.assigns.current_scope.user

    user_params =
      user_params
      |> Map.put("tenant_id", current_user.tenant_id)
      |> Map.put("status", :active)

    case Accounts.create_user(user_params, socket.assigns.current_scope) do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, :unauthorized_role} ->
        {:noreply,
         socket
         |> put_flash(:error, "You cannot create users with super_admin or company_admin roles")
         |> assign_form(Accounts.change_user(socket.assigns.user, user_params))}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have permission to create users")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
