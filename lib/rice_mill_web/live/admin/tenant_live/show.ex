defmodule RiceMillWeb.Admin.TenantLive.Show do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant_with_stats = Accounts.get_tenant_with_stats!(id)
    {:ok, assign(socket, tenant_with_stats: tenant_with_stats)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Show Tenant")
  end

  defp apply_action(socket, :edit, _params) do
    socket
    |> assign(:page_title, "Edit Tenant")
  end

  @impl true
  def handle_event("edit", _params, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/admin/tenants/#{socket.assigns.tenant_with_stats.tenant}/edit")}
  end
end
