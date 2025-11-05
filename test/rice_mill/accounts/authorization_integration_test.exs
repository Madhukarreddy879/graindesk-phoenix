defmodule RiceMill.Accounts.AuthorizationIntegrationTest do
  use RiceMill.DataCase

  alias RiceMill.Accounts
  alias RiceMill.Accounts.Authorization
  alias RiceMill.Accounts.Scope

  describe "authorization integration with Accounts context" do
    setup do
      # Create a tenant for testing
      {:ok, tenant} =
        Accounts.create_tenant(%{name: "Test Company", slug: "test-company", status: "active"})

      # Create users with different roles
      # Super admin should not have tenant_id
      {:ok, super_admin} =
        Accounts.register_user(%{
          email: "superadmin@example.com",
          password: "password123",
          role: "super_admin",
          tenant_id: nil,
          status: "active"
        })

      {:ok, company_admin} =
        Accounts.register_user(%{
          email: "admin@example.com",
          password: "password123",
          role: "company_admin",
          tenant_id: tenant.id,
          status: "active"
        })

      {:ok, operator} =
        Accounts.register_user(%{
          email: "operator@example.com",
          password: "password123",
          role: "operator",
          tenant_id: tenant.id,
          status: "active"
        })

      {:ok, viewer} =
        Accounts.register_user(%{
          email: "viewer@example.com",
          password: "password123",
          role: "viewer",
          tenant_id: tenant.id,
          status: "active"
        })

      %{
        tenant: tenant,
        super_admin: super_admin,
        company_admin: company_admin,
        operator: operator,
        viewer: viewer
      }
    end

    test "super_admin can manage all resources", %{super_admin: super_admin, tenant: tenant} do
      scope = %Scope{user: super_admin}

      # Super admin can manage users in any tenant
      assert Authorization.can?(scope, :manage_users, %{tenant_id: tenant.id})
      assert Authorization.can?(scope, :manage_users, %{tenant_id: "other_tenant"})

      # Super admin can manage tenants
      assert Authorization.can?(scope, :manage_tenants, nil)

      # Super admin can view audit logs for any tenant
      assert Authorization.can?(scope, :view_audit_logs, %{tenant_id: tenant.id})
      assert Authorization.can?(scope, :view_audit_logs, %{tenant_id: "other_tenant"})

      # Super admin can manage inventory and view reports
      assert Authorization.can?(scope, :manage_inventory, %{tenant_id: tenant.id})
      assert Authorization.can?(scope, :view_reports, %{tenant_id: tenant.id})
    end

    test "company_admin can manage users and audit logs in their tenant only", %{
      company_admin: company_admin,
      tenant: tenant
    } do
      scope = %Scope{user: company_admin}

      # Company admin can manage users in their tenant
      assert Authorization.can?(scope, :manage_users, %{tenant_id: tenant.id})

      # Company admin cannot manage users in other tenants
      refute Authorization.can?(scope, :manage_users, %{tenant_id: "other_tenant"})

      # Company admin can view audit logs in their tenant
      assert Authorization.can?(scope, :view_audit_logs, %{tenant_id: tenant.id})

      # Company admin cannot view audit logs in other tenants
      refute Authorization.can?(scope, :view_audit_logs, %{tenant_id: "other_tenant"})

      # Company admin cannot manage tenants
      refute Authorization.can?(scope, :manage_tenants, nil)

      # Company admin can manage inventory and view reports
      assert Authorization.can?(scope, :manage_inventory, %{tenant_id: tenant.id})
      assert Authorization.can?(scope, :view_reports, %{tenant_id: tenant.id})
    end

    test "operator can only manage inventory and view reports in their tenant", %{
      operator: operator,
      tenant: tenant
    } do
      scope = %Scope{user: operator}

      # Operator cannot manage users
      refute Authorization.can?(scope, :manage_users, %{tenant_id: tenant.id})

      # Operator cannot view audit logs
      refute Authorization.can?(scope, :view_audit_logs, %{tenant_id: tenant.id})

      # Operator cannot manage tenants
      refute Authorization.can?(scope, :manage_tenants, nil)

      # Operator can manage inventory in their tenant
      assert Authorization.can?(scope, :manage_inventory, %{tenant_id: tenant.id})

      # Operator cannot manage inventory in other tenants
      refute Authorization.can?(scope, :manage_inventory, %{tenant_id: "other_tenant"})

      # Operator can view reports in their tenant
      assert Authorization.can?(scope, :view_reports, %{tenant_id: tenant.id})

      # Operator cannot view reports in other tenants
      refute Authorization.can?(scope, :view_reports, %{tenant_id: "other_tenant"})
    end

    test "viewer can only view reports in their tenant", %{viewer: viewer, tenant: tenant} do
      scope = %Scope{user: viewer}

      # Viewer cannot manage users
      refute Authorization.can?(scope, :manage_users, %{tenant_id: tenant.id})

      # Viewer cannot view audit logs
      refute Authorization.can?(scope, :view_audit_logs, %{tenant_id: tenant.id})

      # Viewer cannot manage tenants
      refute Authorization.can?(scope, :manage_tenants, nil)

      # Viewer cannot manage inventory
      refute Authorization.can?(scope, :manage_inventory, %{tenant_id: tenant.id})

      # Viewer can view reports in their tenant
      assert Authorization.can?(scope, :view_reports, %{tenant_id: tenant.id})

      # Viewer cannot view reports in other tenants
      refute Authorization.can?(scope, :view_reports, %{tenant_id: "other_tenant"})
    end

    test "authorize! raises exception for unauthorized access", %{viewer: viewer} do
      scope = %Scope{user: viewer}

      # Should raise exception for unauthorized action
      assert_raise RuntimeError, ~r/Unauthorized access/, fn ->
        Authorization.authorize!(scope, :manage_users, %{tenant_id: viewer.tenant_id})
      end
    end

    test "authorize! returns :ok for authorized access", %{
      company_admin: company_admin,
      tenant: tenant
    } do
      scope = %Scope{user: company_admin}

      # Should return :ok for authorized action
      assert Authorization.authorize!(scope, :manage_users, %{tenant_id: tenant.id}) == :ok
    end
  end
end
