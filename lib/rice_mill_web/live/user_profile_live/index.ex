defmodule RiceMillWeb.UserProfileLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts
  alias RiceMill.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    current_user = socket.assigns.current_scope.user
    user = Accounts.get_user!(current_user.id, socket.assigns.current_scope)

    # Get user's recent activity
    activity_logs = get_user_activity(user)

    # Store current session token to preserve it when changing password
    current_token = Map.get(session, "user_token")

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:activity_logs, activity_logs)
     |> assign(:current_token, current_token)
     |> assign(:profile_form, to_form(Accounts.change_user(user)))
     |> assign(:password_form, to_form(Accounts.change_user_password(user), as: :password))
     |> assign(:show_password_form, false)}
  end

  @impl true
  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :profile_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_profile", %{"user" => user_params}, socket) do
    # Only allow updating name and contact_phone
    allowed_params = Map.take(user_params, ["name", "contact_phone"])

    case Accounts.update_user(socket.assigns.user, allowed_params, socket.assigns.current_scope) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully")
         |> assign(:user, updated_user)
         |> assign(:profile_form, to_form(Accounts.change_user(updated_user)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_password_form", _params, socket) do
    {:noreply, assign(socket, :show_password_form, !socket.assigns.show_password_form)}
  end

  @impl true
  def handle_event("validate_password", %{"password" => password_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(password_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :password_form, to_form(changeset, as: :password))}
  end

  @impl true
  def handle_event("change_password", %{"password" => password_params}, socket) do
    user = socket.assigns.user

    # Verify current password
    current_password = Map.get(password_params, "current_password", "")

    if User.valid_password?(user, current_password) do
      # Update password and preserve current session
      current_token = socket.assigns.current_token

      case Accounts.update_user_password(user, password_params, current_token) do
        {:ok, {_updated_user, _tokens}} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             "Password changed successfully. All other sessions have been logged out."
           )
           |> assign(:password_form, to_form(Accounts.change_user_password(user), as: :password))
           |> assign(:show_password_form, false)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :password_form, to_form(changeset, as: :password))}
      end
    else
      changeset =
        socket.assigns.user
        |> Accounts.change_user_password(password_params)
        |> Ecto.Changeset.add_error(:current_password, "is incorrect")
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, :password_form, to_form(changeset, as: :password))}
    end
  end

  defp get_user_activity(user) do
    if user.tenant_id do
      Accounts.get_user_activity(user.id, user.tenant_id, %{limit: 10})
    else
      []
    end
  end

  defp format_role(role) do
    role
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_status(status) do
    status
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp format_action(action) do
    action
    |> String.replace(".", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end
end
