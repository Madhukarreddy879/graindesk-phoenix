defmodule RiceMillWeb.Admin.AuditLogLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts
  alias RiceMill.Accounts.AuditLog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page, 1)
     |> assign(:per_page, 50)
     |> assign(:filters, %{})
     |> assign(:tenants, list_tenants_for_filter(socket))
     |> assign(:action_types, list_action_types())
     |> load_audit_logs()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Audit Logs")
  end

  @impl true
  def handle_event("filter", %{"filters" => filter_params}, socket) do
    filters = build_filters(filter_params)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:page, 1)
     |> load_audit_logs()}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, %{})
     |> assign(:page, 1)
     |> load_audit_logs()}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    {:noreply,
     socket
     |> update(:page, &(&1 + 1))
     |> load_audit_logs()}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    page = max(socket.assigns.page - 1, 1)

    {:noreply,
     socket
     |> assign(:page, page)
     |> load_audit_logs()}
  end

  @impl true
  def handle_event("export", _params, socket) do
    csv_content = generate_csv_export(socket)

    {:noreply,
     socket
     |> push_event("download", %{
       filename: "audit_logs_#{Date.utc_today()}.csv",
       content: csv_content,
       mime_type: "text/csv"
     })}
  end

  defp load_audit_logs(socket) do
    current_user = socket.assigns.current_scope.user
    filters = socket.assigns.filters
    page = socket.assigns.page
    per_page = socket.assigns.per_page

    # Determine which tenant(s) to query based on user role
    tenant_filter =
      case current_user.role do
        :super_admin ->
          # Super admin can see all logs or filter by tenant
          Map.get(filters, :tenant_id)

        :company_admin ->
          # Company admin can only see their tenant's logs
          current_user.tenant_id

        _ ->
          # Other roles shouldn't access this page, but just in case
          nil
      end

    audit_logs = list_audit_logs_with_pagination(tenant_filter, filters, page, per_page)
    total_count = count_audit_logs(tenant_filter, filters)
    has_next = total_count > page * per_page
    has_prev = page > 1

    socket
    |> assign(:audit_logs, audit_logs)
    |> assign(:total_count, total_count)
    |> assign(:has_next, has_next)
    |> assign(:has_prev, has_prev)
  end

  defp list_audit_logs_with_pagination(tenant_id, filters, page, per_page) do
    import Ecto.Query
    offset = (page - 1) * per_page

    query = build_audit_log_query(tenant_id, filters)

    query
    |> limit(^per_page)
    |> offset(^offset)
    |> RiceMill.Repo.all()
    |> RiceMill.Repo.preload([:user, :tenant])
  end

  defp count_audit_logs(tenant_id, filters) do
    query = build_audit_log_query(tenant_id, filters)
    RiceMill.Repo.aggregate(query, :count, :id)
  end

  defp build_audit_log_query(tenant_id, filters) do
    import Ecto.Query

    query = from(a in AuditLog, order_by: [desc: a.inserted_at])

    # Apply tenant filter
    query =
      if tenant_id do
        from(a in query, where: a.tenant_id == ^tenant_id)
      else
        query
      end

    # Apply additional filters
    query =
      Enum.reduce(filters, query, fn
        {:user_id, user_id}, query when not is_nil(user_id) ->
          from(a in query, where: a.user_id == ^user_id)

        {:action, action}, query when not is_nil(action) and action != "" ->
          from(a in query, where: a.action == ^action)

        {:date_from, date_from}, query when not is_nil(date_from) ->
          from(a in query, where: a.inserted_at >= ^date_from)

        {:date_to, date_to}, query when not is_nil(date_to) ->
          # Add one day to include the entire end date
          date_to_end = DateTime.add(date_to, 1, :day)
          from(a in query, where: a.inserted_at < ^date_to_end)

        {:resource_type, resource_type}, query
        when not is_nil(resource_type) and resource_type != "" ->
          from(a in query, where: a.resource_type == ^resource_type)

        _, query ->
          query
      end)

    query
  end

  defp build_filters(filter_params) do
    %{}
    |> maybe_add_filter(:tenant_id, filter_params["tenant_id"])
    |> maybe_add_filter(:user_id, filter_params["user_id"])
    |> maybe_add_filter(:action, filter_params["action"])
    |> maybe_add_filter(:resource_type, filter_params["resource_type"])
    |> maybe_add_date_filter(:date_from, filter_params["date_from"])
    |> maybe_add_date_filter(:date_to, filter_params["date_to"])
  end

  defp maybe_add_filter(filters, _key, value) when value in [nil, ""], do: filters

  defp maybe_add_filter(filters, key, value) do
    Map.put(filters, key, value)
  end

  defp maybe_add_date_filter(filters, _key, value) when value in [nil, ""], do: filters

  defp maybe_add_date_filter(filters, key, date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        # Convert to DateTime at start of day
        datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        Map.put(filters, key, datetime)

      _ ->
        filters
    end
  end

  defp list_tenants_for_filter(socket) do
    current_user = socket.assigns.current_scope.user

    case current_user.role do
      :super_admin ->
        Accounts.list_tenants()

      _ ->
        []
    end
  end

  defp list_action_types do
    [
      "user.created",
      "user.updated",
      "user.deleted",
      "user.activated",
      "user.deactivated",
      "tenant.created",
      "tenant.updated",
      "tenant.deleted",
      "login.success",
      "login.failed",
      "logout",
      "password.reset",
      "password.changed",
      "invitation.sent",
      "invitation.accepted",
      "users.imported"
    ]
  end

  defp generate_csv_export(socket) do
    current_user = socket.assigns.current_scope.user
    filters = socket.assigns.filters

    # Determine tenant filter
    tenant_filter =
      case current_user.role do
        :super_admin -> Map.get(filters, :tenant_id)
        :company_admin -> current_user.tenant_id
        _ -> nil
      end

    # Get all audit logs (without pagination for export)
    audit_logs = list_all_audit_logs_for_export(tenant_filter, filters)

    # Generate CSV content
    csv_header = "Timestamp,User Email,Tenant,Action,Resource Type,Resource ID,IP Address\n"

    csv_rows =
      Enum.map(audit_logs, fn log ->
        [
          format_datetime(log.inserted_at),
          (log.user && log.user.email) || "N/A",
          (log.tenant && log.tenant.name) || "N/A",
          log.action,
          log.resource_type || "N/A",
          log.resource_id || "N/A",
          log.ip_address || "N/A"
        ]
        |> Enum.map(&escape_csv_field/1)
        |> Enum.join(",")
      end)
      |> Enum.join("\n")

    csv_header <> csv_rows
  end

  defp list_all_audit_logs_for_export(tenant_id, filters) do
    query = build_audit_log_query(tenant_id, filters)

    query
    |> RiceMill.Repo.all()
    |> RiceMill.Repo.preload([:user, :tenant])
  end

  defp escape_csv_field(field) when is_binary(field) do
    if String.contains?(field, [",", "\"", "\n"]) do
      "\"#{String.replace(field, "\"", "\"\"")}\""
    else
      field
    end
  end

  defp escape_csv_field(field), do: to_string(field)

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_action(action) do
    action
    |> String.replace("_", " ")
    |> String.replace(".", " - ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp action_badge_class(action) do
    cond do
      String.contains?(action, "created") -> "bg-green-100 text-green-800"
      String.contains?(action, "updated") -> "bg-blue-100 text-blue-800"
      String.contains?(action, "deleted") -> "bg-red-100 text-red-800"
      String.contains?(action, "activated") -> "bg-green-100 text-green-800"
      String.contains?(action, "deactivated") -> "bg-yellow-100 text-yellow-800"
      String.contains?(action, "login") -> "bg-purple-100 text-purple-800"
      String.contains?(action, "logout") -> "bg-gray-100 text-gray-800"
      String.contains?(action, "password") -> "bg-orange-100 text-orange-800"
      String.contains?(action, "invitation") -> "bg-indigo-100 text-indigo-800"
      String.contains?(action, "imported") -> "bg-teal-100 text-teal-800"
      true -> "bg-gray-100 text-gray-800"
    end
  end

  defp format_date_input(nil), do: ""

  defp format_date_input(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_date()
    |> Date.to_iso8601()
  end

  defp format_date_input(_), do: ""
end
