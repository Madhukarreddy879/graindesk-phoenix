defmodule RiceMillWeb.Admin.DashboardLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts

  @impl true
  def mount(_params, _session, socket) do
    stats = get_dashboard_stats()

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:stats, stats)

    {:ok, socket}
  end

  defp get_dashboard_stats do
    %{
      total_tenants: Accounts.count_tenants(),
      active_tenants: Accounts.count_active_tenants(),
      inactive_tenants: Accounts.count_inactive_tenants(),
      total_users: Accounts.count_all_users(),
      recent_tenants: Accounts.list_recent_tenants(5)
    }
  end
end
