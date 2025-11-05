defmodule RiceMillWeb.UserInvitationLive.Accept do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts
  alias RiceMill.Accounts.User

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_invitation_by_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(:page_title, "Invalid Invitation")
         |> assign(:invitation, nil)
         |> assign(:error, :not_found)}

      invitation ->
        # Check if invitation is expired or already accepted
        cond do
          invitation.status == :accepted ->
            {:ok,
             socket
             |> assign(:page_title, "Invitation Already Used")
             |> assign(:invitation, invitation)
             |> assign(:error, :already_accepted)}

          invitation.status == :expired ->
            {:ok,
             socket
             |> assign(:page_title, "Invitation Expired")
             |> assign(:invitation, invitation)
             |> assign(:error, :expired)}

          DateTime.compare(DateTime.utc_now(), invitation.expires_at) == :gt ->
            {:ok,
             socket
             |> assign(:page_title, "Invitation Expired")
             |> assign(:invitation, invitation)
             |> assign(:error, :expired)}

          true ->
            # Valid invitation - show registration form
            changeset = User.password_changeset(%User{}, %{})

            {:ok,
             socket
             |> assign(:page_title, "Accept Invitation")
             |> assign(:invitation, invitation)
             |> assign(:error, nil)
             |> assign(:token, token)
             |> assign_form(changeset)}
        end
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.password_changeset(user_params, hash_password: false)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    token = socket.assigns.token
    invitation = socket.assigns.invitation

    # Prepare user attributes
    user_attrs = %{
      name: user_params["name"],
      password: user_params["password"],
      password_confirmation: user_params["password_confirmation"]
    }

    case Accounts.accept_invitation(token, user_attrs) do
      {:ok, _user} ->
        # Redirect to login page with success message
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Welcome to #{invitation.tenant.name}! Your account has been created successfully. Please log in."
         )
         |> redirect(to: ~p"/users/log-in")}

      {:error, :invitation_not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Invitation not found.")
         |> assign(:error, :not_found)}

      {:error, :invitation_expired} ->
        {:noreply,
         socket
         |> put_flash(:error, "This invitation has expired.")
         |> assign(:error, :expired)}

      {:error, :invitation_already_accepted} ->
        {:noreply,
         socket
         |> put_flash(:error, "This invitation has already been used.")
         |> assign(:error, :already_accepted)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Please fix the errors below.")
         |> assign_form(changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
