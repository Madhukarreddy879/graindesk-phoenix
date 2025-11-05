defmodule RiceMillWeb.Plugs.RequireRoleTest do
  use RiceMillWeb.ConnCase, async: true

  alias RiceMill.Accounts
  alias RiceMillWeb.Plugs.RequireRole

  setup do
    # Create a tenant for testing
    {:ok, tenant} =
      Accounts.create_tenant(%{
        name: "Test Tenant",
        slug: "test-tenant",
        active: true,
        contact_email: "contact@test.com",
        contact_phone: "1234567890"
      })

    # Create test users with different roles
    {:ok, super_admin} =
      Accounts.register_user(%{
        email: "super_admin@example.com",
        password: "password123",
        role: :super_admin,
        status: :active
      })

    {:ok, company_admin} =
      Accounts.register_user(%{
        email: "company_admin@example.com",
        password: "password123",
        role: :company_admin,
        status: :active,
        tenant_id: tenant.id
      })

    {:ok, operator} =
      Accounts.register_user(%{
        email: "operator@example.com",
        password: "password123",
        role: :operator,
        status: :active,
        tenant_id: tenant.id
      })

    {:ok, viewer} =
      Accounts.register_user(%{
        email: "viewer@example.com",
        password: "password123",
        role: :viewer,
        status: :active,
        tenant_id: tenant.id
      })

    %{super_admin: super_admin, company_admin: company_admin, operator: operator, viewer: viewer}
  end

  describe "init/1" do
    test "accepts a single role as atom" do
      assert RequireRole.init(:super_admin) == [:super_admin]
    end

    test "accepts a list of roles" do
      assert RequireRole.init([:super_admin, :company_admin]) == [:super_admin, :company_admin]
    end
  end

  describe "call/2 with super_admin role requirement" do
    test "allows access for super_admin user", %{conn: conn, super_admin: super_admin} do
      conn =
        conn
        |> assign(:current_scope, %{user: super_admin})
        |> RequireRole.call([:super_admin])

      refute conn.halted
    end

    test "denies access for company_admin user", %{conn: conn, company_admin: company_admin} do
      conn =
        conn
        |> assign(:current_scope, %{user: company_admin})
        |> RequireRole.call([:super_admin])

      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "denies access for operator user", %{conn: conn, operator: operator} do
      conn =
        conn
        |> assign(:current_scope, %{user: operator})
        |> RequireRole.call([:super_admin])

      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "denies access for viewer user", %{conn: conn, viewer: viewer} do
      conn =
        conn
        |> assign(:current_scope, %{user: viewer})
        |> RequireRole.call([:super_admin])

      assert conn.halted
      assert redirected_to(conn) == "/"
    end
  end

  describe "call/2 with multiple roles requirement" do
    test "allows access for super_admin user", %{conn: conn, super_admin: super_admin} do
      conn =
        conn
        |> assign(:current_scope, %{user: super_admin})
        |> RequireRole.call([:super_admin, :company_admin])

      refute conn.halted
    end

    test "allows access for company_admin user", %{conn: conn, company_admin: company_admin} do
      conn =
        conn
        |> assign(:current_scope, %{user: company_admin})
        |> RequireRole.call([:super_admin, :company_admin])

      refute conn.halted
    end

    test "denies access for operator user", %{conn: conn, operator: operator} do
      conn =
        conn
        |> assign(:current_scope, %{user: operator})
        |> RequireRole.call([:super_admin, :company_admin])

      assert conn.halted
      assert redirected_to(conn) == "/"
    end
  end

  describe "call/2 with no current_scope" do
    test "passes through when no current_scope is set", %{conn: conn} do
      conn =
        conn
        |> assign(:current_scope, nil)
        |> RequireRole.call([:super_admin])

      refute conn.halted
    end

    test "passes through when current_scope has no user", %{conn: conn} do
      conn =
        conn
        |> assign(:current_scope, %{user: nil})
        |> RequireRole.call([:super_admin])

      refute conn.halted
    end
  end

  # TODO: Add authorization failure logging test when log_action/4 is implemented in Task 13
  # describe "authorization failure logging" do
  #   test "logs authorization failure when access is denied", %{conn: conn, operator: operator} do
  #     # Mock the log_action function to capture the call
  #     import ExUnit.CaptureLog

  #     log_output = capture_log(fn ->
  #       conn
  #       |> assign(:current_scope, %{user: operator})
  #       |> assign(:request_path, "/admin/users")
  #       |> RequireRole.call([:super_admin])
  #     end)

  #     # The log should contain information about the authorization failure
  #     assert log_output =~ "authorization.failed"
  #   end
  # end
end
