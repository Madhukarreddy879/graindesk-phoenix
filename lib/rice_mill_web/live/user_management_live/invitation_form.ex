defmodule RiceMillWeb.UserManagementLive.InvitationForm do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts
  alias RiceMill.Accounts.UserInvitation

  @impl true
  def mount(_params, _session, socket) do
    changeset = UserInvitation.changeset(%UserInvitation{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "Invite User")
     |> assign(:show_preview, false)
     |> assign(:invitation_url, nil)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user_invitation" => invitation_params}, socket) do
    changeset =
      %UserInvitation{}
      |> UserInvitation.changeset(invitation_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("preview", %{"user_invitation" => invitation_params}, socket) do
    changeset =
      %UserInvitation{}
      |> UserInvitation.changeset(invitation_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      # Generate preview URL (this will be the actual URL when sent)
      preview_url = url(~p"/invitations/#{UserInvitation.generate_token()}/accept")

      {:noreply,
       socket
       |> assign(:show_preview, true)
       |> assign(:invitation_url, preview_url)
       |> assign_form(changeset)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Please fix the errors before previewing")
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("send", %{"user_invitation" => invitation_params}, socket) do
    current_user = socket.assigns.current_scope.user

    # Add tenant_id from current user
    invitation_params =
      invitation_params
      |> Map.put("tenant_id", current_user.tenant_id)

    # Validate role - company admins can only invite operator or viewer
    role = Map.get(invitation_params, "role")

    if role in ["operator", "viewer"] do
      # Create invitation URL function
      invitation_url_fun = fn token ->
        url(~p"/invitations/#{token}/accept")
      end

      case Accounts.create_invitation_and_send_email(
             invitation_params,
             current_user,
             invitation_url_fun
           ) do
        {:ok, _invitation} ->
          {:noreply,
           socket
           |> put_flash(:info, "Invitation sent successfully to #{invitation_params["email"]}")
           |> push_navigate(to: ~p"/users/manage")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to send invitation")
           |> assign_form(changeset)}
      end
    else
      changeset =
        %UserInvitation{}
        |> UserInvitation.changeset(invitation_params)
        |> Ecto.Changeset.add_error(
          :role,
          "You can only invite users with operator or viewer roles"
        )

      {:noreply,
       socket
       |> put_flash(:error, "You cannot invite users with super_admin or company_admin roles")
       |> assign_form(changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
