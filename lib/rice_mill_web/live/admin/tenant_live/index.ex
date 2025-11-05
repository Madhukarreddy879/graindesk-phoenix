defmodule RiceMillWeb.Admin.TenantLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts
  alias RiceMill.Accounts.Tenant

  @impl true
  def mount(_params, _session, socket) do
    tenants = list_tenants()

    socket =
      socket
      |> assign(:search_query, "")
      |> assign(:tenants_empty?, tenants == [])
      |> stream_configure(:tenants, dom_id: fn %{tenant: tenant} -> "tenant-#{tenant.id}" end)
      |> stream(:tenants, tenants)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Tenant")
    |> assign(:tenant, Accounts.get_tenant!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Tenant")
    |> assign(:tenant, %Tenant{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Tenants")
    |> assign(:tenant, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    tenant = Accounts.get_tenant!(id)
    {:ok, _} = Accounts.delete_tenant(tenant)

    {:noreply, stream_delete(socket, :tenants, tenant)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    tenants = search_tenants(query)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:tenants_empty?, tenants == [])
     |> stream(:tenants, tenants, reset: true)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    tenants = list_tenants()

    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:tenants_empty?, tenants == [])
     |> stream(:tenants, tenants, reset: true)}
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    tenant = Accounts.get_tenant!(id)
    {:ok, _tenant} = Accounts.activate_tenant(tenant, socket.assigns.current_scope.user)

    # Get updated stats for the tenant
    tenant_with_stats = Accounts.get_tenant_with_stats!(id)
    {:noreply, stream_insert(socket, :tenants, tenant_with_stats)}
  end

  @impl true
  def handle_event("deactivate", %{"id" => id}, socket) do
    tenant = Accounts.get_tenant!(id)
    {:ok, _tenant} = Accounts.deactivate_tenant(tenant, socket.assigns.current_scope.user)

    # Get updated stats for the tenant
    tenant_with_stats = Accounts.get_tenant_with_stats!(id)
    {:noreply, stream_insert(socket, :tenants, tenant_with_stats)}
  end

  defp list_tenants do
    Accounts.list_tenants_with_stats()
  end

  defp search_tenants(query) when query == "" or query == nil do
    list_tenants()
  end

  defp search_tenants(query) do
    Accounts.search_tenants_with_stats(query)
  end
end
