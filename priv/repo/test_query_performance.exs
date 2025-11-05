# Script to test query performance and execution plans
# Run with: mix run priv/repo/test_query_performance.exs

alias RiceMill.Repo
alias RiceMill.Dashboard
import Ecto.Query

# Get a tenant_id from the database
tenant = Repo.one(from t in RiceMill.Accounts.Tenant, limit: 1)

if tenant do
  IO.puts("\n=== Testing Dashboard Query Performance ===")
  IO.puts("Tenant ID: #{tenant.id}\n")

  # Test 1: Inventory Metrics Query
  IO.puts("1. Testing Inventory Metrics Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_inventory_metrics(tenant.id)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  # Test 2: Financial Metrics Query
  IO.puts("2. Testing Financial Metrics Query...")
  date_range = Dashboard.calculate_date_range("this_month")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_financial_metrics(tenant.id, date_range)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  # Test 3: Stock Movement Data Query
  IO.puts("3. Testing Stock Movement Data Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_stock_movement_data(tenant.id, date_range)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  # Test 4: Top Products Query
  IO.puts("4. Testing Top Products Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_top_products(tenant.id, date_range)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  # Test 5: Top Farmers Query
  IO.puts("5. Testing Top Farmers Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_top_farmers(tenant.id, date_range)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  # Test 6: Top Customers Query
  IO.puts("6. Testing Top Customers Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_top_customers(tenant.id, date_range)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  # Test 7: Stock Alerts Query
  IO.puts("7. Testing Stock Alerts Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_stock_alerts(tenant.id)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  # Test 8: Performance Comparison Query
  IO.puts("8. Testing Performance Comparison Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_performance_comparison(tenant.id, date_range)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  # Test 9: Recent Transactions Queries
  IO.puts("9. Testing Recent Stock-Ins Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_recent_stock_ins(tenant.id, 10)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  IO.puts("10. Testing Recent Stock-Outs Query...")

  {time_micro, _result} =
    :timer.tc(fn ->
      Dashboard.get_recent_stock_outs(tenant.id, 10)
    end)

  IO.puts("   Execution time: #{time_micro / 1000} ms\n")

  IO.puts("=== All queries completed successfully ===")
  IO.puts("\nNote: Query times include caching overhead on first run.")
  IO.puts("Subsequent runs will be faster due to caching.\n")
else
  IO.puts("No tenant found in database. Please create a tenant first.")
end
