defmodule RiceMillWeb.UserManagementLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts
  alias RiceMill.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :users, list_users(socket))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, Accounts.get_user!(id, socket.assigns.current_scope))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Users")
    |> assign(:user, nil)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    users = search_users(socket, query)
    {:noreply, assign(socket, :users, users)}
  end

  @impl true
  def handle_event("reset_password", %{"id" => id}, socket) do
    user = Accounts.get_user!(id, socket.assigns.current_scope)

    case Accounts.reset_user_password(user, send_email: true) do
      {:ok, {_updated_user, temp_password}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully. Temporary password: #{temp_password}")
         |> assign(:users, list_users(socket))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to reset password")}
    end
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    user = Accounts.get_user!(id, socket.assigns.current_scope)

    case Accounts.activate_user(user, socket.assigns.current_scope) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User activated successfully")
         |> assign(:users, list_users(socket))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to activate this user")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to activate user")}
    end
  end

  @impl true
  def handle_event("deactivate", %{"id" => id}, socket) do
    user = Accounts.get_user!(id, socket.assigns.current_scope)

    case Accounts.deactivate_user(user, socket.assigns.current_scope) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User deactivated successfully")
         |> assign(:users, list_users(socket))}

      {:error, :cannot_deactivate_self} ->
        {:noreply, put_flash(socket, :error, "You cannot deactivate your own account")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to deactivate this user")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to deactivate user")}
    end
  end

  @impl true
  def handle_info({RiceMillWeb.UserManagementLive.FormComponent, {:saved, _user}}, socket) do
    {:noreply, assign(socket, :users, list_users(socket))}
  end

  defp list_users(socket) do
    # Company admins can only see users in their tenant
    current_user = socket.assigns.current_scope.user

    if current_user.tenant_id do
      Accounts.list_users_for_tenant(current_user.tenant_id)
    else
      []
    end
  end

  defp search_users(socket, query) when query == "" or query == nil do
    list_users(socket)
  end

  defp search_users(socket, query) do
    current_user = socket.assigns.current_scope.user

    # Parse search query to determine filter type
    cond do
      String.contains?(query, "@") ->
        # Search by email
        Accounts.list_users_for_tenant(current_user.tenant_id, %{email: query})

      query in ["operator", "viewer", "company_admin"] ->
        # Search by role
        role = String.to_existing_atom(query)
        Accounts.list_users_for_tenant(current_user.tenant_id, %{role: role})

      true ->
        # Search by email pattern
        Accounts.list_users_for_tenant(current_user.tenant_id, %{email: query})
    end
  end
end
