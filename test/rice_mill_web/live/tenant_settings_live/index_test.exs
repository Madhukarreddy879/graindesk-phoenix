defmodule RiceMillWeb.TenantSettingsLive.IndexTest do
  use RiceMillWeb.ConnCase
  import Phoenix.LiveViewTest
  import RiceMill.AccountsFixtures
  alias RiceMill.Accounts

  describe "Index" do
    setup %{conn: conn} do
      tenant = tenant_fixture()
      user = user_fixture(%{role: :company_admin, tenant_id: tenant.id})

      conn = log_in_user(conn, user)
      %{conn: conn, tenant: tenant, user: user}
    end

    test "renders tenant settings form", %{conn: conn, tenant: tenant} do
      {:ok, _index_live, html} = live(conn, ~p"/settings/tenant")

      assert html =~ "Tenant Settings"
      assert html =~ "Basic Information"
      assert html =~ "Preferences"
      assert html =~ "Current Settings"
      assert html =~ tenant.name
      assert html =~ tenant.slug
    end

    test "allows updating tenant basic information", %{conn: conn, tenant: tenant} do
      {:ok, index_live, _html} = live(conn, ~p"/settings/tenant")

      new_name = "Updated Tenant Name"
      new_email = "updated@example.com"

      index_live
      |> form("#tenant-form",
        tenant: %{
          "name" => new_name,
          "slug" => tenant.slug,
          "contact_email" => new_email,
          "contact_phone" => "1234567890"
        }
      )
      |> render_submit()

      assert render(index_live) =~ "Tenant settings updated successfully"
      assert render(index_live) =~ new_name
      assert render(index_live) =~ new_email
    end

    test "allows updating tenant settings", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/settings/tenant")

      index_live
      |> form("#tenant-form",
        tenant: %{
          "default_unit" => "lbs",
          "timezone" => "America/New_York",
          "date_format" => "MM/DD/YYYY"
        }
      )
      |> render_submit()

      assert render(index_live) =~ "Tenant settings updated successfully"
      assert render(index_live) =~ "lbs"
      assert render(index_live) =~ "America/New_York"
      assert render(index_live) =~ "MM/DD/YYYY"
    end

    test "displays current settings", %{conn: conn} do
      {:ok, index_live, html} = live(conn, ~p"/settings/tenant")

      assert html =~ "Current Settings"
      assert html =~ "Default Unit"
      assert html =~ "Timezone"
      assert html =~ "Date Format"
    end

    test "requires company_admin or super_admin role", %{conn: conn} do
      # Test with operator role (should be redirected)
      operator_user = user_fixture(%{role: :operator, tenant_id: tenant_fixture().id})
      conn = log_in_user(conn, operator_user)

      assert_raise RiceMillWeb.AuthorizationError, fn ->
        live(conn, ~p"/settings/tenant")
      end
    end

    test "allows super_admin role", %{conn: conn} do
      # Create super admin user (tenant_id must be nil)
      super_admin = unconfirmed_user_fixture(%{role: :super_admin, tenant_id: nil})

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(super_admin, url)
        end)

      {:ok, {super_admin, _expired_tokens}} = Accounts.login_user_by_magic_link(token)
      conn = log_in_user(conn, super_admin)

      {:ok, _index_live, html} = live(conn, ~p"/settings/tenant")
      assert html =~ "Tenant Settings"
    end
  end
end
