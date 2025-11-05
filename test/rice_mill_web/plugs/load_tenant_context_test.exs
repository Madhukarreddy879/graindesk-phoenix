defmodule RiceMillWeb.Plugs.LoadTenantContextTest do
  use RiceMillWeb.ConnCase, async: true

  alias RiceMillWeb.Plugs.LoadTenantContext

  describe "call/2" do
    setup do
      # Create a test tenant
      tenant = tenant_fixture()

      # Create users with different roles
      user_with_tenant = user_fixture(%{tenant_id: tenant.id, role: :company_admin})
      super_admin = user_fixture(%{role: :super_admin})
      operator = user_fixture(%{tenant_id: tenant.id, role: :operator})

      %{
        tenant: tenant,
        user_with_tenant: user_with_tenant,
        super_admin: super_admin,
        operator: operator
      }
    end

    test "loads tenant for user with tenant_id", %{
      conn: conn,
      tenant: tenant,
      user_with_tenant: user
    } do
      conn =
        conn
        |> assign(:current_user, user)
        |> LoadTenantContext.call([])

      assert conn.assigns[:current_tenant].id == tenant.id
      assert conn.assigns[:current_tenant].name == tenant.name
      assert conn.assigns[:current_tenant].slug == tenant.slug
    end

    test "assigns nil tenant for super admin", %{conn: conn, super_admin: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> LoadTenantContext.call([])

      assert conn.assigns[:current_tenant] == nil
    end

    test "loads tenant for operator user", %{conn: conn, tenant: tenant, operator: user} do
      conn =
        conn
        |> assign(:current_user, user)
        |> LoadTenantContext.call([])

      assert conn.assigns[:current_tenant].id == tenant.id
      assert conn.assigns[:current_tenant].name == tenant.name
    end

    test "continues without tenant when user has no tenant_id", %{conn: conn} do
      user = %{id: Ecto.UUID.generate(), role: :operator, tenant_id: nil}

      conn =
        conn
        |> assign(:current_user, user)
        |> LoadTenantContext.call([])

      refute Map.has_key?(conn.assigns, :current_tenant)
    end

    test "continues without tenant when no current_user", %{conn: conn} do
      conn = LoadTenantContext.call(conn, [])
      refute Map.has_key?(conn.assigns, :current_tenant)
    end

    test "continues without tenant when tenant not found", %{conn: conn} do
      user = %{id: Ecto.UUID.generate(), role: :company_admin, tenant_id: Ecto.UUID.generate()}

      conn =
        conn
        |> assign(:current_user, user)
        |> LoadTenantContext.call([])

      refute Map.has_key?(conn.assigns, :current_tenant)
    end

    test "handles conn with existing assigns", %{
      conn: conn,
      tenant: tenant,
      user_with_tenant: user
    } do
      conn =
        conn
        |> assign(:current_user, user)
        |> assign(:some_other_assign, "test_value")
        |> LoadTenantContext.call([])

      assert conn.assigns[:current_tenant].id == tenant.id
      assert conn.assigns[:some_other_assign] == "test_value"
    end
  end

  describe "init/1" do
    test "returns the given options" do
      assert LoadTenantContext.init([]) == []
      assert LoadTenantContext.init(some: :option) == [some: :option]
    end
  end

  # Helper functions
  defp tenant_fixture(attrs \\ %{}) do
    {:ok, tenant} =
      attrs
      |> Enum.into(%{
        name: "Test Tenant",
        slug: "test-tenant-#{System.unique_integer([:positive])}",
        contact_email: "contact@example.com",
        contact_phone: "1234567890",
        active: true
      })
      |> then(&RiceMill.Accounts.Tenant.changeset(%RiceMill.Accounts.Tenant{}, &1))
      |> RiceMill.Repo.insert()

    tenant
  end

  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "test-#{System.unique_integer([:positive])}@example.com",
        password: "password123",
        role: :company_admin,
        status: :active
      })
      |> RiceMill.Accounts.register_user()

    user
  end
end
