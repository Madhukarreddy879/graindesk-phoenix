defmodule RiceMillWeb.Plugs.TenantContext do
  @moduledoc """
  Plug to set tenant context from authenticated user.

  This plug loads the tenant record for the current user's tenant_id and assigns
  it to the connection as :current_tenant for use in LiveViews and controllers.

  For super admins (who have nil tenant_id), no tenant is loaded.
  """
  import Plug.Conn
  alias RiceMill.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_scope] do
      %{user: %{tenant_id: tenant_id}} when not is_nil(tenant_id) ->
        # Load tenant record for the user's tenant_id
        try do
          tenant = Accounts.get_tenant!(tenant_id)

          conn
          |> assign(:current_tenant_id, tenant_id)
          |> assign(:current_tenant, tenant)
        rescue
          Ecto.NoResultsError ->
            # Tenant not found, continue without tenant context
            assign(conn, :current_tenant_id, tenant_id)
        end

      %{user: %{role: :super_admin}} ->
        # Super admin can access all tenants, no tenant context set by default
        conn
        |> assign(:current_tenant_id, nil)
        |> assign(:current_tenant, nil)

      _ ->
        # No authenticated user or no tenant_id, continue without tenant context
        conn
    end
  end
end
