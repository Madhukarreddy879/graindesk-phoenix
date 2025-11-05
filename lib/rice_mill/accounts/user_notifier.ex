defmodule RiceMill.Accounts.UserNotifier do
  import Swoosh.Email

  alias RiceMill.Mailer
  alias RiceMill.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"RiceMill", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver password reset instructions with temporary password.
  """
  def deliver_password_reset(user, temp_password) do
    deliver(user.email, "Password Reset Instructions", """

    ==============================

    Hi #{user.email},

    Your password has been reset by an administrator.

    Your temporary password is: #{temp_password}

    Please log in with this temporary password and change it immediately.

    If you didn't request this password reset, please contact your administrator immediately.

    ==============================
    """)
  end

  @doc """
  Deliver user invitation email with invitation acceptance URL.
  """
  def deliver_user_invitation(user_invitation, invitation_url) do
    deliver(user_invitation.email, "User Invitation - Rice Mill Inventory System", """

    ==============================

    Hello,

    You have been invited to join the Rice Mill Inventory System as a #{user_invitation.role}.

    To accept this invitation and create your account, please visit the following URL:

    #{invitation_url}

    This invitation will expire on #{format_datetime(user_invitation.expires_at)}.

    If you did not expect this invitation, please ignore this email.

    ==============================
    """)
  end

  @doc """
  Deliver welcome email for new users.
  """
  def deliver_welcome_email(user, _invited_by \\ nil) do
    deliver(user.email, "Welcome to Rice Mill Inventory System", """

    ==============================

    Hi #{user.name || user.email},

    Welcome to the Rice Mill Inventory System!

    Your account has been created successfully. You can now log in using your email address.

    To access the system, please visit the login page and enter your credentials.

    If you have any questions or need assistance, please contact your system administrator.

    Thank you for joining us!

    ==============================
    """)
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
  end
end
