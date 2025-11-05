defmodule RiceMillWeb.DashboardLive.PdfExport do
  @moduledoc """
  Handles PDF export generation for dashboard reports.
  """

  @doc """
  Generates a PDF report from dashboard data.

  Returns `{:ok, pdf_path, filename}` on success or `{:error, reason}` on failure.
  """
  def generate_pdf(assigns) do
    # Render the HTML template
    html_content = render_template(assigns)

    # Generate filename with current date
    filename = "dashboard-report-#{Date.utc_today()}.pdf"
    output_path = Path.join(System.tmp_dir!(), filename)

    # Generate PDF from HTML
    case PdfGenerator.generate(html_content, page_size: "A4", delete_temporary: true) do
      {:ok, pdf_path} ->
        # Move to our desired location
        File.cp!(pdf_path, output_path)
        File.rm(pdf_path)
        {:ok, output_path, filename}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp render_template(assigns) do
    # Build HTML content directly
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Dashboard Report</title>
      #{css_styles()}
    </head>
    <body>
      #{render_header(assigns)}
      #{render_meta_info(assigns)}
      #{render_inventory_summary(assigns)}
      #{render_financial_metrics(assigns)}
      #{render_performance_comparison(assigns)}
      #{render_stock_alerts(assigns)}
      #{render_top_products(assigns)}
      #{render_top_farmers(assigns)}
      #{render_top_customers(assigns)}
      #{render_footer()}
    </body>
    </html>
    """
  end

  defp css_styles do
    """
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 12px; line-height: 1.5; color: #1f2937; padding: 20px; }
      .header { border-bottom: 3px solid #3b82f6; padding-bottom: 15px; margin-bottom: 20px; }
      .header h1 { font-size: 24px; font-weight: 700; color: #1f2937; margin-bottom: 5px; }
      .header .subtitle { font-size: 14px; color: #6b7280; }
      .meta-info { display: flex; justify-content: space-between; margin-bottom: 20px; padding: 10px; background-color: #f3f4f6; border-radius: 4px; }
      .meta-info div { flex: 1; }
      .meta-info .label { font-size: 10px; color: #6b7280; text-transform: uppercase; font-weight: 600; margin-bottom: 2px; }
      .meta-info .value { font-size: 12px; color: #1f2937; font-weight: 500; }
      .section { margin-bottom: 25px; page-break-inside: avoid; }
      .section-title { font-size: 16px; font-weight: 600; color: #1f2937; margin-bottom: 10px; padding-bottom: 5px; border-bottom: 2px solid #e5e7eb; }
      .metrics-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin-bottom: 15px; }
      .metric-card { border: 1px solid #e5e7eb; border-radius: 4px; padding: 12px; background-color: #ffffff; }
      .metric-label { font-size: 10px; color: #6b7280; text-transform: uppercase; font-weight: 600; margin-bottom: 4px; }
      .metric-value { font-size: 20px; font-weight: 700; color: #1f2937; }
      .metric-unit { font-size: 11px; color: #6b7280; font-weight: 400; }
      .metric-subtext { font-size: 10px; color: #6b7280; margin-top: 4px; }
      .positive { color: #10b981; }
      .negative { color: #ef4444; }
      table { width: 100%; border-collapse: collapse; margin-top: 10px; }
      table thead { background-color: #f9fafb; }
      table th { padding: 8px; text-align: left; font-size: 10px; font-weight: 600; color: #6b7280; text-transform: uppercase; border-bottom: 2px solid #e5e7eb; }
      table th.text-right { text-align: right; }
      table td { padding: 8px; font-size: 11px; color: #1f2937; border-bottom: 1px solid #f3f4f6; }
      table td.text-right { text-align: right; }
      .alert-badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 10px; font-weight: 600; }
      .alert-badge.low { background-color: #fef3c7; color: #92400e; }
      .alert-badge.out { background-color: #fee2e2; color: #991b1b; }
      .footer { margin-top: 30px; padding-top: 15px; border-top: 1px solid #e5e7eb; text-align: center; font-size: 10px; color: #9ca3af; }
      .two-column { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
    </style>
    """
  end

  defp render_header(assigns) do
    """
    <div class="header">
      <h1>Dashboard Report</h1>
      <div class="subtitle">#{assigns.tenant_name}</div>
    </div>
    """
  end

  defp render_meta_info(assigns) do
    """
    <div class="meta-info">
      <div>
        <div class="label">Report Period</div>
        <div class="value">#{format_period(assigns.time_period)}</div>
      </div>
      <div>
        <div class="label">Generated On</div>
        <div class="value">#{format_datetime(assigns.generated_at)}</div>
      </div>
      <div>
        <div class="label">Date Range</div>
        <div class="value">#{format_date(assigns.date_range_start)} - #{format_date(assigns.date_range_end)}</div>
      </div>
    </div>
    """
  end

  defp render_inventory_summary(assigns) do
    metrics = assigns.inventory_metrics

    """
    <div class="section">
      <h2 class="section-title">Inventory Summary</h2>
      <div class="metrics-grid">
        <div class="metric-card">
          <div class="metric-label">Total Stock</div>
          <div class="metric-value">#{format_number(metrics.total_stock)} <span class="metric-unit">quintals</span></div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Products</div>
          <div class="metric-value">#{metrics.product_count}</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Total Value</div>
          <div class="metric-value">₹#{format_number(metrics.total_value)}</div>
        </div>
      </div>
    </div>
    """
  end

  defp render_financial_metrics(%{can_view_financial: false}), do: ""

  defp render_financial_metrics(assigns) do
    metrics = assigns.financial_metrics
    margin_class = if metrics.gross_margin >= 0, do: "positive", else: "negative"

    """
    <div class="section">
      <h2 class="section-title">Financial Metrics</h2>
      <div class="metrics-grid">
        <div class="metric-card">
          <div class="metric-label">Total Purchases</div>
          <div class="metric-value">₹#{format_number(metrics.total_purchases)}</div>
          <div class="metric-subtext">#{metrics.stock_in_count} transactions</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Total Sales</div>
          <div class="metric-value">₹#{format_number(metrics.total_sales)}</div>
          <div class="metric-subtext">#{metrics.stock_out_count} transactions</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Gross Margin</div>
          <div class="metric-value #{margin_class}">₹#{format_number(metrics.gross_margin)}</div>
        </div>
      </div>
    </div>
    """
  end

  defp render_performance_comparison(assigns) do
    comp = assigns.performance_comparison
    stock_in_class = if comp.stock_in_change >= 0, do: "positive", else: "negative"
    stock_out_class = if comp.stock_out_change >= 0, do: "positive", else: "negative"
    stock_in_sign = if comp.stock_in_change >= 0, do: "+", else: ""
    stock_out_sign = if comp.stock_out_change >= 0, do: "+", else: ""

    """
    <div class="section">
      <h2 class="section-title">Performance Comparison</h2>
      <div class="two-column">
        <div class="metric-card">
          <div class="metric-label">Stock-In Volume</div>
          <div class="metric-value">#{format_number(comp.current_stock_in)} <span class="metric-unit">quintals</span></div>
          <div class="metric-subtext #{stock_in_class}">#{stock_in_sign}#{format_percentage(comp.stock_in_change)}% vs previous period</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">Stock-Out Volume</div>
          <div class="metric-value">#{format_number(comp.current_stock_out)} <span class="metric-unit">quintals</span></div>
          <div class="metric-subtext #{stock_out_class}">#{stock_out_sign}#{format_percentage(comp.stock_out_change)}% vs previous period</div>
        </div>
      </div>
    </div>
    """
  end

  defp render_stock_alerts(%{stock_alerts: []}), do: ""

  defp render_stock_alerts(assigns) do
    alerts_html =
      Enum.map(assigns.stock_alerts, fn alert ->
        badge_class = if alert.severity == :out_of_stock, do: "out", else: "low"
        badge_text = if alert.severity == :out_of_stock, do: "Out of Stock", else: "Low Stock"

        """
        <tr>
          <td>#{alert.product_name}</td>
          <td class="text-right">#{format_number(alert.current_stock)} quintals</td>
          <td class="text-right"><span class="alert-badge #{badge_class}">#{badge_text}</span></td>
        </tr>
        """
      end)
      |> Enum.join()

    """
    <div class="section">
      <h2 class="section-title">Stock Alerts (#{length(assigns.stock_alerts)})</h2>
      <table>
        <thead>
          <tr>
            <th>Product Name</th>
            <th class="text-right">Current Stock</th>
            <th class="text-right">Status</th>
          </tr>
        </thead>
        <tbody>
          #{alerts_html}
        </tbody>
      </table>
    </div>
    """
  end

  defp render_top_products(assigns) do
    stock_in_rows =
      if assigns.top_products.stock_in == [] do
        "<tr><td colspan='3' style='text-align: center; color: #9ca3af; padding: 20px;'>No data available</td></tr>"
      else
        Enum.map(assigns.top_products.stock_in, fn product ->
          """
          <tr>
            <td>#{product.product_name}</td>
            <td class="text-right">#{format_number(product.quantity)} quintals</td>
            <td class="text-right">#{product.percentage}%</td>
          </tr>
          """
        end)
        |> Enum.join()
      end

    stock_out_rows =
      if assigns.top_products.stock_out == [] do
        "<tr><td colspan='3' style='text-align: center; color: #9ca3af; padding: 20px;'>No data available</td></tr>"
      else
        Enum.map(assigns.top_products.stock_out, fn product ->
          """
          <tr>
            <td>#{product.product_name}</td>
            <td class="text-right">#{format_number(product.quantity)} quintals</td>
            <td class="text-right">#{product.percentage}%</td>
          </tr>
          """
        end)
        |> Enum.join()
      end

    """
    <div class="section">
      <h2 class="section-title">Top Products by Stock-In</h2>
      <table>
        <thead>
          <tr>
            <th>Product Name</th>
            <th class="text-right">Quantity</th>
            <th class="text-right">Percentage</th>
          </tr>
        </thead>
        <tbody>
          #{stock_in_rows}
        </tbody>
      </table>
    </div>
    <div class="section">
      <h2 class="section-title">Top Products by Stock-Out</h2>
      <table>
        <thead>
          <tr>
            <th>Product Name</th>
            <th class="text-right">Quantity</th>
            <th class="text-right">Percentage</th>
          </tr>
        </thead>
        <tbody>
          #{stock_out_rows}
        </tbody>
      </table>
    </div>
    """
  end

  defp render_top_farmers(%{can_view_financial: false}), do: ""
  defp render_top_farmers(%{top_farmers: []}), do: ""

  defp render_top_farmers(assigns) do
    rows =
      Enum.map(assigns.top_farmers, fn farmer ->
        """
        <tr>
          <td>#{farmer.farmer_name}</td>
          <td class="text-right">#{format_number(farmer.total_quantity)} quintals</td>
          <td class="text-right">₹#{format_number(farmer.total_amount)}</td>
          <td class="text-right">#{farmer.transaction_count}</td>
        </tr>
        """
      end)
      |> Enum.join()

    """
    <div class="section">
      <h2 class="section-title">Top Farmers</h2>
      <table>
        <thead>
          <tr>
            <th>Farmer Name</th>
            <th class="text-right">Quantity</th>
            <th class="text-right">Amount</th>
            <th class="text-right">Transactions</th>
          </tr>
        </thead>
        <tbody>
          #{rows}
        </tbody>
      </table>
    </div>
    """
  end

  defp render_top_customers(%{can_view_financial: false}), do: ""
  defp render_top_customers(%{top_customers: []}), do: ""

  defp render_top_customers(assigns) do
    rows =
      Enum.map(assigns.top_customers, fn customer ->
        """
        <tr>
          <td>#{customer.customer_name}</td>
          <td class="text-right">#{format_number(customer.total_quantity)} quintals</td>
          <td class="text-right">₹#{format_number(customer.total_amount)}</td>
          <td class="text-right">#{customer.transaction_count}</td>
        </tr>
        """
      end)
      |> Enum.join()

    """
    <div class="section">
      <h2 class="section-title">Top Customers</h2>
      <table>
        <thead>
          <tr>
            <th>Customer Name</th>
            <th class="text-right">Quantity</th>
            <th class="text-right">Amount</th>
            <th class="text-right">Transactions</th>
          </tr>
        </thead>
        <tbody>
          #{rows}
        </tbody>
      </table>
    </div>
    """
  end

  defp render_footer do
    """
    <div class="footer">
      <p>This report was automatically generated by Rice Mill Inventory Management System</p>
      <p>© #{DateTime.utc_now().year} Rice Mill. All rights reserved.</p>
    </div>
    """
  end

  # Helper functions for formatting

  defp format_number(nil), do: "0"

  defp format_number(number) when is_float(number) do
    number
    |> Decimal.from_float()
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_with_commas()
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Decimal.new()
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_with_commas()
  end

  defp format_number(number) when is_binary(number) do
    case Decimal.parse(number) do
      {decimal, _} ->
        decimal
        |> Decimal.round(2)
        |> Decimal.to_string()
        |> format_with_commas()

      :error ->
        number
    end
  end

  defp format_number(%Decimal{} = number) do
    number
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_with_commas()
  end

  defp format_with_commas(number_string) do
    [integer_part, decimal_part] =
      case String.split(number_string, ".") do
        [int] -> [int, nil]
        [int, dec] -> [int, dec]
      end

    formatted_integer =
      integer_part
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.reverse/1)
      |> Enum.reverse()
      |> Enum.map(&Enum.join/1)
      |> Enum.join(",")

    if decimal_part do
      "#{formatted_integer}.#{decimal_part}"
    else
      formatted_integer
    end
  end

  defp format_percentage(number) when is_float(number) or is_integer(number) do
    number
    |> abs()
    |> :erlang.float_to_binary(decimals: 1)
  end

  defp format_percentage(%Decimal{} = number) do
    number
    |> Decimal.abs()
    |> Decimal.round(1)
    |> Decimal.to_string()
  end

  defp format_period("today"), do: "Today"
  defp format_period("this_week"), do: "This Week"
  defp format_period("this_month"), do: "This Month"
  defp format_period("last_month"), do: "Last Month"
  defp format_period("this_quarter"), do: "This Quarter"
  defp format_period("this_year"), do: "This Year"
  defp format_period(period), do: String.capitalize(period)

  defp format_datetime(datetime) when is_struct(datetime, DateTime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp format_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> format_datetime()
  end

  defp format_datetime(_), do: "Unknown"

  defp format_date(date) when is_struct(date, Date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_date(_), do: "Unknown"
end
