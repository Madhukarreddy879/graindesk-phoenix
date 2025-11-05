defmodule RiceMill.AccountsTest do
  use RiceMill.DataCase

  alias RiceMill.Accounts

  import RiceMill.AccountsFixtures
  alias RiceMill.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture() |> set_password()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture() |> set_password()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:status, :email]
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "clears password_reset_required flag when updating password", %{user: user} do
      # Set the password_reset_required flag
      {:ok, user} = Accounts.require_password_change(user)
      assert user.password_reset_required == true

      # Update password
      {:ok, {updated_user, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert updated_user.password_reset_required == false
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "get_user_by_magic_link_token/1" do
    setup do
      user = user_fixture()
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      %{user: user, token: encoded_token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_magic_link_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_magic_link_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_magic_link_token(token)
    end
  end

  describe "login_user_by_magic_link/1" do
    test "confirms user and expires tokens" do
      user = unconfirmed_user_fixture()
      refute user.confirmed_at
      {encoded_token, hashed_token} = generate_user_magic_link_token(user)

      assert {:ok, {user, [%{token: ^hashed_token}]}} =
               Accounts.login_user_by_magic_link(encoded_token)

      assert user.confirmed_at
    end

    test "returns user and (deleted) token for confirmed user" do
      user = user_fixture()
      assert user.confirmed_at
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)
      assert {:ok, {^user, []}} = Accounts.login_user_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_user_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed user has password set" do
      user = unconfirmed_user_fixture()
      {1, nil} = Repo.update_all(User, set: [hashed_password: "hashed"])
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_user_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{user: unconfirmed_user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "login"
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  describe "log_action/3" do
    setup do
      tenant = tenant_fixture()
      user = user_fixture(%{tenant_id: tenant.id})
      %{user: user, tenant: tenant}
    end

    test "creates an audit log entry", %{user: user} do
      changes = %{name: "John Doe", email: "john@example.com"}

      assert {:ok, audit_log} =
               Accounts.log_action(user, "user.create", %{
                 resource_type: "User",
                 resource_id: Ecto.UUID.generate(),
                 changes: changes,
                 ip_address: "192.168.1.1",
                 user_agent: "Mozilla/5.0"
               })

      assert audit_log.action == "user.create"
      assert audit_log.user_id == user.id
      assert audit_log.tenant_id == user.tenant_id
      assert audit_log.resource_type == "User"
      assert audit_log.changes == changes
      assert audit_log.ip_address == "192.168.1.1"
      assert audit_log.user_agent == "Mozilla/5.0"
    end

    test "requires action field", %{user: user} do
      assert {:error, changeset} = Accounts.log_action(user, nil, %{})
      assert "can't be blank" in errors_on(changeset).action
    end

    test "validates IP address format", %{user: user} do
      assert {:error, changeset} =
               Accounts.log_action(user, "user.create", %{
                 ip_address: "invalid_ip"
               })

      assert "must be a valid IP address" in errors_on(changeset).ip_address
    end

    test "accepts valid IPv4 address", %{user: user} do
      assert {:ok, audit_log} =
               Accounts.log_action(user, "user.create", %{
                 ip_address: "192.168.1.1"
               })

      assert audit_log.ip_address == "192.168.1.1"
    end

    test "accepts valid IPv6 address", %{user: user} do
      assert {:ok, audit_log} =
               Accounts.log_action(user, "user.create", %{
                 ip_address: "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
               })

      assert audit_log.ip_address == "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    end
  end

  describe "list_audit_logs/2" do
    setup do
      tenant = tenant_fixture()
      user1 = user_fixture(%{tenant_id: tenant.id})
      user2 = user_fixture(%{tenant_id: tenant.id})

      # Create some audit logs
      {:ok, _} =
        Accounts.log_action(user1, "user.create", %{
          resource_type: "User",
          changes: %{name: "User 1"}
        })

      {:ok, _} =
        Accounts.log_action(user2, "user.update", %{
          resource_type: "User",
          changes: %{name: "User 2"}
        })

      {:ok, _} =
        Accounts.log_action(user1, "user.delete", %{
          resource_type: "User",
          changes: %{id: "some-id"}
        })

      %{tenant: tenant, user1: user1, user2: user2}
    end

    test "lists all audit logs for a tenant", %{tenant: tenant} do
      audit_logs = Accounts.list_audit_logs(tenant.id)
      assert length(audit_logs) == 3

      # Should be ordered by inserted_at desc (most recent first)
      # But if timestamps are identical, they may come in chronological order
      assert Enum.map(audit_logs, & &1.action) == ["user.create", "user.update", "user.delete"]
    end

    test "filters by action", %{tenant: tenant} do
      audit_logs = Accounts.list_audit_logs(tenant.id, %{action: "user.create"})
      assert length(audit_logs) == 1
      assert hd(audit_logs).action == "user.create"
    end

    test "filters by resource_type", %{tenant: tenant} do
      audit_logs = Accounts.list_audit_logs(tenant.id, %{resource_type: "User"})
      assert length(audit_logs) == 3
    end

    test "limits results", %{tenant: tenant} do
      audit_logs = Accounts.list_audit_logs(tenant.id, %{limit: 2})
      assert length(audit_logs) == 2
    end

    test "combines multiple filters", %{tenant: tenant} do
      audit_logs =
        Accounts.list_audit_logs(tenant.id, %{
          action: "user.create",
          limit: 1
        })

      assert length(audit_logs) == 1
      assert hd(audit_logs).action == "user.create"
    end
  end

  describe "get_user_activity/3" do
    setup do
      tenant = tenant_fixture()
      user = user_fixture(%{tenant_id: tenant.id})

      # Create audit logs for this user
      {:ok, _} =
        Accounts.log_action(user, "user.login", %{
          ip_address: "192.168.1.1"
        })

      {:ok, _} =
        Accounts.log_action(user, "user.update", %{
          changes: %{name: "Updated Name"}
        })

      {:ok, _} =
        Accounts.log_action(user, "user.logout", %{
          ip_address: "192.168.1.1"
        })

      # Create audit log for different user
      other_user = user_fixture(%{tenant_id: tenant.id})

      {:ok, _} =
        Accounts.log_action(other_user, "user.login", %{
          ip_address: "192.168.1.2"
        })

      %{tenant: tenant, user: user, other_user: other_user}
    end

    test "gets activity for specific user", %{tenant: tenant, user: user} do
      activity = Accounts.get_user_activity(user.id, tenant.id)
      assert length(activity) == 3
      assert Enum.all?(activity, fn log -> log.user_id == user.id end)
    end

    test "limits user activity results", %{tenant: tenant, user: user} do
      activity = Accounts.get_user_activity(user.id, tenant.id, %{limit: 2})
      assert length(activity) == 2
    end

    test "returns empty list for user with no activity", %{
      tenant: tenant,
      other_user: _other_user
    } do
      # Create a user with no activity
      new_user = user_fixture(%{tenant_id: tenant.id})
      activity = Accounts.get_user_activity(new_user.id, tenant.id)
      assert activity == []
    end
  end

  describe "list_tenants_with_stats/1" do
    setup do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})

      user1 =
        user_fixture(%{
          tenant_id: tenant.id,
          email: "user1@example.com",
          status: :active,
          confirmed_at: DateTime.utc_now()
        })

      user2 =
        user_fixture(%{
          tenant_id: tenant.id,
          email: "user2@example.com",
          status: :active,
          confirmed_at: DateTime.utc_now()
        })

      user3 = user_fixture(%{tenant_id: tenant.id, email: "user3@example.com", status: :inactive})

      # Create audit logs for activity
      {:ok, _} =
        Accounts.log_action(user1, "user.login", %{
          ip_address: "192.168.1.1",
          inserted_at: DateTime.add(DateTime.utc_now(), -1, :hour)
        })

      {:ok, _} =
        Accounts.log_action(user2, "user.update", %{
          changes: %{name: "Updated Name"},
          inserted_at: DateTime.add(DateTime.utc_now(), -2, :hour)
        })

      %{tenant: tenant, user1: user1, user2: user2, user3: user3}
    end

    test "returns tenants with statistics", %{tenant: tenant} do
      tenants_with_stats = Accounts.list_tenants_with_stats()

      tenant_stats = Enum.find(tenants_with_stats, fn ts -> ts.tenant.id == tenant.id end)
      assert tenant_stats
      assert tenant_stats.tenant.name == "Test Tenant"
      assert tenant_stats.user_count == 3
      assert tenant_stats.active_users == 2
      assert tenant_stats.inactive_users == 1
      assert tenant_stats.last_activity != nil
    end

    test "respects limit parameter" do
      # Create additional tenants
      tenant_fixture(%{name: "Tenant 2", slug: "tenant-2"})
      tenant_fixture(%{name: "Tenant 3", slug: "tenant-3"})

      tenants_with_stats = Accounts.list_tenants_with_stats(%{limit: 2})
      assert length(tenants_with_stats) == 2
    end

    test "filters by active status" do
      tenant_fixture(%{name: "Inactive Tenant", slug: "inactive-tenant", active: false})

      active_tenants = Accounts.list_tenants_with_stats(%{active: true})
      assert Enum.all?(active_tenants, fn ts -> ts.tenant.active == true end)

      inactive_tenants = Accounts.list_tenants_with_stats(%{active: false})
      assert Enum.all?(inactive_tenants, fn ts -> ts.tenant.active == false end)
    end
  end

  describe "get_tenant_with_stats!/1" do
    setup do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})

      user1 =
        user_fixture(%{
          tenant_id: tenant.id,
          email: "user1@example.com",
          status: :active,
          confirmed_at: DateTime.utc_now()
        })

      user2 =
        user_fixture(%{
          tenant_id: tenant.id,
          email: "user2@example.com",
          status: :active,
          confirmed_at: DateTime.utc_now()
        })

      user3 = user_fixture(%{tenant_id: tenant.id, email: "user3@example.com", status: :inactive})

      # Create audit logs for activity
      {:ok, _} =
        Accounts.log_action(user1, "user.login", %{
          ip_address: "192.168.1.1",
          inserted_at: DateTime.add(DateTime.utc_now(), -1, :hour)
        })

      {:ok, _} =
        Accounts.log_action(user2, "user.update", %{
          changes: %{name: "Updated Name"},
          inserted_at: DateTime.add(DateTime.utc_now(), -2, :hour)
        })

      %{tenant: tenant, user1: user1, user2: user2, user3: user3}
    end

    test "returns tenant with detailed statistics", %{tenant: tenant, user1: user1, user2: user2} do
      tenant_with_stats = Accounts.get_tenant_with_stats!(tenant.id)

      assert tenant_with_stats.tenant.id == tenant.id
      assert tenant_with_stats.tenant.name == "Test Tenant"
      assert tenant_with_stats.user_count == 3
      assert tenant_with_stats.active_users == 2
      assert tenant_with_stats.last_activity != nil
      assert length(tenant_with_stats.users) == 3

      # Check that users are ordered by inserted_at desc
      users = tenant_with_stats.users
      assert Enum.all?(users, fn u -> u.tenant_id == tenant.id end)
    end

    test "raises if tenant does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_tenant_with_stats!(Ecto.UUID.generate())
      end
    end

    test "handles tenant with no users" do
      empty_tenant = tenant_fixture(%{name: "Empty Tenant", slug: "empty-tenant"})
      tenant_with_stats = Accounts.get_tenant_with_stats!(empty_tenant.id)

      assert tenant_with_stats.tenant.id == empty_tenant.id
      assert tenant_with_stats.user_count == 0
      assert tenant_with_stats.active_users == 0
      assert tenant_with_stats.last_activity == nil
      assert tenant_with_stats.users == []
    end
  end

  describe "create_tenant_with_admin/2" do
    test "creates tenant with admin user" do
      {:ok, result} =
        Accounts.create_tenant_with_admin(
          %{
            name: "New Tenant",
            slug: "new-tenant",
            contact_email: "admin@newtenant.com",
            contact_phone: "+1234567890"
          },
          "admin@newtenant.com"
        )

      assert result.tenant.name == "New Tenant"
      assert result.tenant.slug == "new-tenant"
      assert result.tenant.contact_email == "admin@newtenant.com"
      assert result.tenant.contact_phone == "+1234567890"
      assert result.tenant.active == true

      assert result.admin_user.email == "admin@newtenant.com"
      assert result.admin_user.name == "Admin"
      assert result.admin_user.role == :admin
      assert result.admin_user.tenant_id == result.tenant.id
      assert result.admin_user.status == :active
      assert result.admin_user.confirmed_at != nil
      assert result.admin_user.password_reset_required == true

      # Verify password was set
      assert result.admin_user.hashed_password != nil
    end

    test "validates required fields" do
      {:error, changeset} = Accounts.create_tenant_with_admin(%{}, "admin@example.com")
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).slug
    end

    test "validates email format" do
      {:error, changeset} =
        Accounts.create_tenant_with_admin(
          %{
            name: "New Tenant",
            slug: "new-tenant"
          },
          "invalid-email"
        )

      assert "must have the @ sign and no spaces" in errors_on(changeset).admin_email
    end

    test "ensures slug uniqueness" do
      tenant_fixture(%{name: "Existing Tenant", slug: "existing-tenant"})

      {:error, changeset} =
        Accounts.create_tenant_with_admin(
          %{
            name: "New Tenant",
            slug: "existing-tenant"
          },
          "admin@example.com"
        )

      assert "has already been taken" in errors_on(changeset).slug
    end
  end

  describe "update_tenant/2" do
    test "updates tenant attributes" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})

      {:ok, updated_tenant} =
        Accounts.update_tenant(tenant, %{
          name: "Updated Tenant",
          contact_email: "updated@example.com",
          contact_phone: "+0987654321"
        })

      assert updated_tenant.name == "Updated Tenant"
      assert updated_tenant.contact_email == "updated@example.com"
      assert updated_tenant.contact_phone == "+0987654321"
      # Should not change
      assert updated_tenant.slug == tenant.slug
    end

    test "validates changes" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})
      {:error, changeset} = Accounts.update_tenant(tenant, %{name: ""})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "maintains slug immutability" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})
      {:ok, updated_tenant} = Accounts.update_tenant(tenant, %{slug: "new-slug"})
      # Should remain unchanged
      assert updated_tenant.slug == tenant.slug
    end
  end

  describe "deactivate_tenant/1" do
    test "deactivates tenant and logs action" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})
      user = user_fixture(%{tenant_id: tenant.id, email: "user@example.com", role: :admin})

      {:ok, deactivated_tenant} = Accounts.deactivate_tenant(tenant, user)

      assert deactivated_tenant.active == false

      # Verify audit log was created
      audit_logs = Accounts.list_audit_logs(tenant.id, %{action: "tenant.deactivate"})
      assert length(audit_logs) == 1
      assert hd(audit_logs).user_id == user.id
    end

    test "idempotent - deactivating already inactive tenant" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})
      user = user_fixture(%{tenant_id: tenant.id, email: "user@example.com", role: :admin})

      # First deactivate
      {:ok, _} = Accounts.deactivate_tenant(tenant, user)

      # Try to deactivate again
      {:ok, still_deactivated} = Accounts.deactivate_tenant(tenant, user)
      assert still_deactivated.active == false
    end

    test "requires admin authorization" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})
      # Not admin
      user = user_fixture(%{tenant_id: tenant.id, email: "user@example.com"})

      # User is not admin by default
      assert_raise RuntimeError, ~r/Unauthorized/, fn ->
        Accounts.deactivate_tenant(tenant, user)
      end
    end
  end

  describe "activate_tenant/1" do
    test "activates tenant and logs action" do
      inactive_tenant =
        tenant_fixture(%{name: "Inactive Tenant", slug: "inactive-tenant", active: false})

      admin_user = user_fixture(%{tenant_id: inactive_tenant.id, role: :admin})

      {:ok, activated_tenant} = Accounts.activate_tenant(inactive_tenant, admin_user)

      assert activated_tenant.active == true

      # Verify audit log was created
      audit_logs = Accounts.list_audit_logs(inactive_tenant.id, %{action: "tenant.activate"})
      assert length(audit_logs) == 1
      assert hd(audit_logs).user_id == admin_user.id
    end

    test "idempotent - activating already active tenant" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant", active: true})
      admin_user = user_fixture(%{tenant_id: tenant.id, role: :admin})

      # Try to activate already active tenant
      {:ok, still_active} = Accounts.activate_tenant(tenant, admin_user)
      assert still_active.active == true
    end

    test "requires admin authorization" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})
      # Not admin
      user = user_fixture(%{tenant_id: tenant.id, email: "user@example.com"})

      assert_raise RuntimeError, ~r/Unauthorized/, fn ->
        Accounts.activate_tenant(tenant, user)
      end
    end
  end

  describe "tenant settings" do
    test "get_tenant_settings/1 returns tenant settings" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})
      settings = Accounts.get_tenant_settings(tenant)
      assert settings == tenant.settings || %{}
    end

    test "update_tenant_settings/2 updates settings" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})

      new_settings = %{
        "theme" => "dark",
        "notifications" => %{
          "email" => true,
          "sms" => false
        }
      }

      {:ok, updated_tenant} = Accounts.update_tenant_settings(tenant, new_settings)
      assert updated_tenant.settings == new_settings

      # Verify settings can be retrieved
      assert Accounts.get_tenant_settings(updated_tenant) == new_settings
    end

    test "update_tenant_settings/2 validates settings structure" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})
      # Test with invalid settings (not a map)
      {:error, changeset} = Accounts.update_tenant_settings(tenant, "invalid")
      assert "must be a map" in errors_on(changeset).settings
    end
  end

  describe "get_tenant_activity_metrics/1" do
    test "returns comprehensive activity metrics" do
      tenant = tenant_fixture(%{name: "Test Tenant", slug: "test-tenant"})

      user1 =
        user_fixture(%{
          tenant_id: tenant.id,
          email: "user1@example.com",
          last_login_at: DateTime.utc_now()
        })

      user2 =
        user_fixture(%{
          tenant_id: tenant.id,
          email: "user2@example.com",
          last_login_at: DateTime.add(DateTime.utc_now(), -10, :day)
        })

      user3 =
        user_fixture(%{tenant_id: tenant.id, email: "user3@example.com", last_login_at: nil})

      # Create more recent activity
      now = DateTime.utc_now()

      # Login within last 7 days
      {:ok, _} =
        Accounts.log_action(user1, "user.login", %{
          ip_address: "192.168.1.1",
          inserted_at: DateTime.add(now, -3, :day)
        })

      # Login within last 30 days but not 7
      {:ok, _} =
        Accounts.log_action(user1, "user.login", %{
          ip_address: "192.168.1.1",
          inserted_at: DateTime.add(now, -15, :day)
        })

      metrics = Accounts.get_tenant_activity_metrics(tenant.id)

      assert metrics.total_users == 3
      assert metrics.active_users == 2
      assert metrics.inactive_users == 1
      assert metrics.last_7_days_logins >= 1
      assert metrics.last_30_days_logins >= 2
      # Limited to 10
      assert length(metrics.recent_activity) == 10

      # Check recent activity structure
      recent_activity = metrics.recent_activity

      assert Enum.all?(recent_activity, fn activity ->
               Map.has_key?(activity, :action) &&
                 Map.has_key?(activity, :timestamp) &&
                 Map.has_key?(activity, :user_email)
             end)
    end

    test "handles tenant with no activity" do
      empty_tenant = tenant_fixture(%{name: "Empty Tenant", slug: "empty-tenant"})
      metrics = Accounts.get_tenant_activity_metrics(empty_tenant.id)

      assert metrics.total_users == 0
      assert metrics.active_users == 0
      assert metrics.inactive_users == 0
      assert metrics.last_7_days_logins == 0
      assert metrics.last_30_days_logins == 0
      assert metrics.recent_activity == []
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "resets user password and sets reset_required flag", %{user: user} do
      {:ok, {updated_user, temp_password}} = Accounts.reset_user_password(user, false)

      assert updated_user.password_reset_required == true
      assert String.length(temp_password) == 16
      assert Accounts.get_user_by_email_and_password(user.email, temp_password)
    end

    test "logs the password reset action", %{user: user} do
      {:ok, {_user, _temp_password}} = Accounts.reset_user_password(user, false)

      audit_logs =
        Accounts.list_audit_logs(user.tenant_id, %{action: "password.reset", user_id: user.id})

      assert length(audit_logs) == 1
    end

    test "generates different temporary passwords each time", %{user: user} do
      {:ok, {_user1, temp_password1}} = Accounts.reset_user_password(user, false)
      {:ok, {_user2, temp_password2}} = Accounts.reset_user_password(user, false)

      assert temp_password1 != temp_password2
    end
  end

  describe "generate_temporary_password/0" do
    test "generates a secure 16-character password" do
      password = Accounts.generate_temporary_password()
      assert String.length(password) == 16

      # Should contain different character types
      assert String.match?(password, ~r/[A-Z]/)
      assert String.match?(password, ~r/[a-z]/)
      assert String.match?(password, ~r/[0-9]/)
      assert String.match?(password, ~r/[!@#$%^&*]/)
    end

    test "generates different passwords each time" do
      password1 = Accounts.generate_temporary_password()
      password2 = Accounts.generate_temporary_password()

      assert password1 != password2
    end
  end

  describe "require_password_change/1" do
    setup do
      %{user: user_fixture()}
    end

    test "sets password_reset_required flag", %{user: user} do
      {:ok, updated_user} = Accounts.require_password_change(user)
      assert updated_user.password_reset_required == true
    end

    test "returns error for invalid user" do
      invalid_user = %{user_fixture() | id: -1}
      assert {:error, _changeset} = Accounts.require_password_change(invalid_user)
    end
  end
end
