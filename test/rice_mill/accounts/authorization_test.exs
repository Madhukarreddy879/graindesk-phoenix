defmodule RiceMill.Accounts.AuthorizationTest do
  use RiceMill.DataCase

  alias RiceMill.Accounts.Authorization
  alias RiceMill.Accounts.{User, Scope}

  describe "can?/3 - nil user" do
    test "returns false for nil user" do
      scope = %Scope{user: nil}
      refute Authorization.can?(scope, :manage_users, %{tenant_id: "123"})
    end
  end

  describe "can?/3 - super_admin" do
    test "super_admin can perform any action" do
      user = %User{id: "1", role: :super_admin, tenant_id: "123", email: "admin@example.com"}
      scope = %Scope{user: user}

      assert Authorization.can?(scope, :manage_users, %{tenant_id: "123"})
      assert Authorization.can?(scope, :manage_tenants, nil)
      assert Authorization.can?(scope, :view_audit_logs, %{tenant_id: "123"})
      assert Authorization.can?(scope, :manage_inventory, %{tenant_id: "123"})
      assert Authorization.can?(scope, :view_reports, %{tenant_id: "123"})
      assert Authorization.can?(scope, :unknown_action, nil)
    end
  end

  describe "can?/3 - company_admin" do
    setup do
      user = %User{id: "2", role: :company_admin, tenant_id: "123", email: "admin@company.com"}
      scope = %Scope{user: user}
      %{scope: scope, tenant_id: "123"}
    end

    test "can manage users in same tenant", %{scope: scope, tenant_id: tenant_id} do
      assert Authorization.can?(scope, :manage_users, %{tenant_id: tenant_id})
    end

    test "cannot manage users in different tenant", %{scope: scope} do
      refute Authorization.can?(scope, :manage_users, %{tenant_id: "456"})
    end

    test "can view audit logs in same tenant", %{scope: scope, tenant_id: tenant_id} do
      assert Authorization.can?(scope, :view_audit_logs, %{tenant_id: tenant_id})
    end

    test "cannot view audit logs in different tenant", %{scope: scope} do
      refute Authorization.can?(scope, :view_audit_logs, %{tenant_id: "456"})
    end

    test "can manage inventory", %{scope: scope} do
      assert Authorization.can?(scope, :manage_inventory, %{tenant_id: "123"})
    end

    test "can view reports", %{scope: scope} do
      assert Authorization.can?(scope, :view_reports, %{tenant_id: "123"})
    end

    test "cannot manage tenants", %{scope: scope} do
      refute Authorization.can?(scope, :manage_tenants, nil)
    end

    test "cannot perform unknown actions", %{scope: scope} do
      refute Authorization.can?(scope, :unknown_action, nil)
    end
  end

  describe "can?/3 - operator" do
    setup do
      user = %User{id: "3", role: :operator, tenant_id: "123", email: "operator@company.com"}
      scope = %Scope{user: user}
      %{scope: scope, tenant_id: "123"}
    end

    test "can manage inventory in same tenant", %{scope: scope, tenant_id: tenant_id} do
      assert Authorization.can?(scope, :manage_inventory, %{tenant_id: tenant_id})
    end

    test "cannot manage inventory in different tenant", %{scope: scope} do
      refute Authorization.can?(scope, :manage_inventory, %{tenant_id: "456"})
    end

    test "can view reports in same tenant", %{scope: scope, tenant_id: tenant_id} do
      assert Authorization.can?(scope, :view_reports, %{tenant_id: tenant_id})
    end

    test "cannot view reports in different tenant", %{scope: scope} do
      refute Authorization.can?(scope, :view_reports, %{tenant_id: "456"})
    end

    test "cannot manage users", %{scope: scope} do
      refute Authorization.can?(scope, :manage_users, %{tenant_id: "123"})
    end

    test "cannot view audit logs", %{scope: scope} do
      refute Authorization.can?(scope, :view_audit_logs, %{tenant_id: "123"})
    end
  end

  describe "can?/3 - viewer" do
    setup do
      user = %User{id: "4", role: :viewer, tenant_id: "123", email: "viewer@company.com"}
      scope = %Scope{user: user}
      %{scope: scope, tenant_id: "123"}
    end

    test "can view reports in same tenant", %{scope: scope, tenant_id: tenant_id} do
      assert Authorization.can?(scope, :view_reports, %{tenant_id: tenant_id})
    end

    test "cannot view reports in different tenant", %{scope: scope} do
      refute Authorization.can?(scope, :view_reports, %{tenant_id: "456"})
    end

    test "cannot manage inventory", %{scope: scope} do
      refute Authorization.can?(scope, :manage_inventory, %{tenant_id: "123"})
    end

    test "cannot manage users", %{scope: scope} do
      refute Authorization.can?(scope, :manage_users, %{tenant_id: "123"})
    end

    test "cannot view audit logs", %{scope: scope} do
      refute Authorization.can?(scope, :view_audit_logs, %{tenant_id: "123"})
    end
  end

  describe "has_role?/2" do
    test "returns false for nil user" do
      scope = %Scope{user: nil}
      refute Authorization.has_role?(scope, [:super_admin, :company_admin])
    end

    test "checks if user has any of the specified roles" do
      user = %User{id: "1", role: :super_admin, tenant_id: "123", email: "admin@example.com"}
      scope = %Scope{user: user}

      assert Authorization.has_role?(scope, [:super_admin, :company_admin])
      assert Authorization.has_role?(scope, :super_admin)
      refute Authorization.has_role?(scope, [:company_admin, :operator])
      refute Authorization.has_role?(scope, :company_admin)
    end
  end

  describe "role-specific check functions" do
    setup do
      super_admin = %User{
        id: "1",
        role: :super_admin,
        tenant_id: "123",
        email: "admin@example.com"
      }

      company_admin = %User{
        id: "2",
        role: :company_admin,
        tenant_id: "123",
        email: "admin@company.com"
      }

      operator = %User{id: "3", role: :operator, tenant_id: "123", email: "operator@company.com"}
      viewer = %User{id: "4", role: :viewer, tenant_id: "123", email: "viewer@company.com"}

      %{
        super_admin_scope: %Scope{user: super_admin},
        company_admin_scope: %Scope{user: company_admin},
        operator_scope: %Scope{user: operator},
        viewer_scope: %Scope{user: viewer}
      }
    end

    test "super_admin?/1", %{
      super_admin_scope: super_admin_scope,
      company_admin_scope: company_admin_scope
    } do
      assert Authorization.super_admin?(super_admin_scope)
      refute Authorization.super_admin?(company_admin_scope)
    end

    test "company_admin?/1", %{
      super_admin_scope: super_admin_scope,
      company_admin_scope: company_admin_scope,
      operator_scope: operator_scope
    } do
      refute Authorization.company_admin?(super_admin_scope)
      assert Authorization.company_admin?(company_admin_scope)
      refute Authorization.company_admin?(operator_scope)
    end

    test "can_manage_users?/2", %{
      super_admin_scope: super_admin_scope,
      company_admin_scope: company_admin_scope,
      operator_scope: operator_scope
    } do
      assert Authorization.can_manage_users?(super_admin_scope, "123")
      assert Authorization.can_manage_users?(super_admin_scope, "456")
      assert Authorization.can_manage_users?(company_admin_scope, "123")
      refute Authorization.can_manage_users?(company_admin_scope, "456")
      refute Authorization.can_manage_users?(operator_scope, "123")
    end

    test "can_manage_tenants?/1", %{
      super_admin_scope: super_admin_scope,
      company_admin_scope: company_admin_scope
    } do
      assert Authorization.can_manage_tenants?(super_admin_scope)
      refute Authorization.can_manage_tenants?(company_admin_scope)
    end

    test "can_view_audit_logs?/2", %{
      super_admin_scope: super_admin_scope,
      company_admin_scope: company_admin_scope,
      operator_scope: operator_scope
    } do
      assert Authorization.can_view_audit_logs?(super_admin_scope, "123")
      assert Authorization.can_view_audit_logs?(super_admin_scope, "456")
      assert Authorization.can_view_audit_logs?(company_admin_scope, "123")
      refute Authorization.can_view_audit_logs?(company_admin_scope, "456")
      refute Authorization.can_view_audit_logs?(operator_scope, "123")
    end

    test "can_manage_inventory?/1", %{
      super_admin_scope: super_admin_scope,
      company_admin_scope: company_admin_scope,
      operator_scope: operator_scope,
      viewer_scope: viewer_scope
    } do
      assert Authorization.can_manage_inventory?(super_admin_scope)
      assert Authorization.can_manage_inventory?(company_admin_scope)
      assert Authorization.can_manage_inventory?(operator_scope)
      refute Authorization.can_manage_inventory?(viewer_scope)
    end

    test "can_view_reports?/1", %{
      super_admin_scope: super_admin_scope,
      company_admin_scope: company_admin_scope,
      operator_scope: operator_scope,
      viewer_scope: viewer_scope
    } do
      assert Authorization.can_view_reports?(super_admin_scope)
      assert Authorization.can_view_reports?(company_admin_scope)
      assert Authorization.can_view_reports?(operator_scope)
      assert Authorization.can_view_reports?(viewer_scope)
    end
  end

  describe "same_tenant?/2" do
    test "returns false for nil user" do
      scope = %Scope{user: nil}
      refute Authorization.same_tenant?(scope, %{tenant_id: "123"})
    end

    test "checks if user and resource are in same tenant" do
      user = %User{id: "1", role: :company_admin, tenant_id: "123", email: "admin@company.com"}
      scope = %Scope{user: user}

      assert Authorization.same_tenant?(scope, %{tenant_id: "123"})
      assert Authorization.same_tenant?(scope, %User{tenant_id: "123"})
      refute Authorization.same_tenant?(scope, %{tenant_id: "456"})
      refute Authorization.same_tenant?(scope, %{tenant_id: nil})
    end
  end

  describe "authorize!/3" do
    test "returns :ok when authorized" do
      user = %User{id: "1", role: :super_admin, tenant_id: "123", email: "admin@example.com"}
      scope = %Scope{user: user}

      assert Authorization.authorize!(scope, :manage_users, %{tenant_id: "123"}) == :ok
    end

    test "raises exception when unauthorized" do
      user = %User{id: "2", role: :company_admin, tenant_id: "123", email: "admin@company.com"}
      scope = %Scope{user: user}

      assert_raise RuntimeError,
                   ~r/Unauthorized access.*User 2 attempted to manage_tenants/,
                   fn ->
                     Authorization.authorize!(scope, :manage_tenants, nil)
                   end
    end

    test "raises exception for nil user" do
      scope = %Scope{user: nil}

      assert_raise RuntimeError,
                   ~r/Unauthorized access.*anonymous attempted to manage_users/,
                   fn ->
                     Authorization.authorize!(scope, :manage_users, %{tenant_id: "123"})
                   end
    end
  end
end
