defmodule RiceMillWeb.DashboardExportController do
  use RiceMillWeb, :controller

  alias RiceMill.Dashboard
  alias RiceMill.Accounts
  alias RiceMillWeb.DashboardLive.PdfExport

  def export(conn, params) do
    current_scope = conn.assigns.current_scope
    user = current_scope.user
    user_role = user.role
    tenant_id = user.tenant_id

    # Fetch tenant
    tenant = Accounts.get_tenant!(tenant_id)

    # Get time period from params or default to this_month
    time_period = params["period"] || "this_month"
    date_range = Dashboard.calculate_date_range(time_period)
    {start_date, end_date} = date_range

    # Fetch all dashboard data
    inventory_metrics = Dashboard.get_inventory_metrics(tenant_id)
    financial_metrics = Dashboard.get_financial_metrics(tenant_id, date_range)
    performance_comparison = Dashboard.get_performance_comparison(tenant_id, date_range)
    stock_alerts = Dashboard.get_stock_alerts(tenant_id)
    top_products = Dashboard.get_top_products(tenant_id, date_range)
    top_farmers = Dashboard.get_top_farmers(tenant_id, date_range)
    top_customers = Dashboard.get_top_customers(tenant_id, date_range)

    can_view_financial = user_role in [:company_admin, :operator]

    # Prepare data for PDF export
    export_assigns = %{
      tenant_name: tenant.name,
      time_period: time_period,
      generated_at: DateTime.utc_now(),
      date_range_start: start_date,
      date_range_end: end_date,
      inventory_metrics: inventory_metrics,
      financial_metrics: financial_metrics,
      performance_comparison: performance_comparison,
      stock_alerts: stock_alerts,
      top_products: top_products,
      top_farmers: if(can_view_financial, do: top_farmers, else: []),
      top_customers: if(can_view_financial, do: top_customers, else: []),
      can_view_financial: can_view_financial
    }

    # Generate PDF
    case PdfExport.generate_pdf(export_assigns) do
      {:ok, pdf_path, filename} ->
        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_file(200, pdf_path)
        |> halt()

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to generate report: #{inspect(reason)}")
        |> redirect(to: ~p"/dashboard")
    end
  end
end
