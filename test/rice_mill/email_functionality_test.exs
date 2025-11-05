defmodule RiceMill.EmailFunctionalityTest do
  use RiceMill.DataCase, async: true

  alias RiceMill.Accounts
  alias RiceMill.Accounts.UserNotifier
  import RiceMill.AccountsFixtures

  describe "invitation email functionality" do
    test "deliver_user_invitation/2 sends invitation email" do
      tenant = tenant_fixture()
      inviter = user_fixture(tenant_id: tenant.id, role: :company_admin)

      # Create an invitation first
      {:ok, invitation} =
        Accounts.create_invitation(
          %{email: "newuser@example.com", role: :operator, tenant_id: tenant.id},
          inviter
        )

      invitation_url = "http://localhost:4000/invitations/accept?token=#{invitation.token}"

      # Capture the email that would be sent
      {:ok, email} = UserNotifier.deliver_user_invitation(invitation, invitation_url)

      # Verify email structure and content
      assert email.to == [{"", invitation.email}]
      assert email.subject == "User Invitation - Rice Mill Inventory System"
      assert email.text_body =~ "You have been invited to join the Rice Mill Inventory System"
      assert email.text_body =~ invitation_url
    end
  end

  describe "welcome email functionality" do
    test "deliver_welcome_email/1 sends welcome email" do
      user = user_fixture()

      # Capture the email that would be sent
      {:ok, email} = UserNotifier.deliver_welcome_email(user)

      # Verify email structure and content
      assert email.to == [{"", user.email}]
      assert email.subject == "Welcome to Rice Mill Inventory System"
      assert email.text_body =~ "Hi #{user.email}"
      assert email.text_body =~ "Welcome to the Rice Mill Inventory System!"
      assert email.text_body =~ "please visit the login page"
    end
  end

  describe "create_invitation_and_send_email/3" do
    test "creates invitation and sends email" do
      tenant = tenant_fixture()
      inviter = user_fixture(%{tenant_id: tenant.id, role: :company_admin})

      # Mock the invitation URL generation function
      invitation_url_fn = fn token ->
        "http://localhost:4000/invitations/accept?token=#{token}"
      end

      # Create invitation and send email
      {:ok, invitation} =
        Accounts.create_invitation_and_send_email(
          %{email: "newuser@example.com", role: :operator, tenant_id: tenant.id},
          inviter,
          invitation_url_fn
        )

      # Verify invitation was created
      assert invitation.email == "newuser@example.com"
      assert invitation.role == :operator
      assert invitation.tenant_id == tenant.id
      assert invitation.status == :pending
      assert invitation.token != nil
    end
  end
end
