defmodule RiceMillWeb.Admin.AdminUserLive.Index do
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
    |> assign(:user, Accounts.get_user!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Users")
    |> assign(:user, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user, socket.assigns.current_scope.user)

    {:noreply, assign(socket, :users, list_users(socket))}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    users = search_users(socket, query)
    {:noreply, assign(socket, :users, users)}
  end

  @impl true
  def handle_event("reset_password", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

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

  defp list_users(socket) do
    Accounts.list_users(socket.assigns.current_scope)
  end

  defp search_users(socket, query) when query == "" or query == nil do
    list_users(socket)
  end

  defp search_users(socket, query) do
    scope = socket.assigns.current_scope

    # Parse search query to determine filter type
    cond do
      String.contains?(query, "@") ->
        # Search by email
        Accounts.list_users(scope, %{email: query})

      query in ["super_admin", "company_admin", "operator", "viewer"] ->
        # Search by role
        role = String.to_existing_atom(query)
        Accounts.list_users(scope, %{role: role})

      true ->
        # Search by email pattern
        Accounts.list_users(scope, %{email: query})
    end
  end
end
