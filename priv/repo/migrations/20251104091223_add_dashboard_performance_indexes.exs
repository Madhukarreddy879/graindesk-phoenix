defmodule RiceMill.Repo.Migrations.AddDashboardPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Index for date-based filtering on stock_ins (composite index for better performance)
    create_if_not_exists index(:stock_ins, [:tenant_id, :date],
                           name: :stock_ins_tenant_date_index
                         )

    # Index for farmer name filtering (composite index)
    create_if_not_exists index(:stock_ins, [:tenant_id, :farmer_name],
                           name: :stock_ins_tenant_farmer_index
                         )

    # Index for customer name filtering (composite index)
    create_if_not_exists index(:stock_outs, [:tenant_id, :customer_name],
                           name: :stock_outs_tenant_customer_index
                         )

    # Index for product-based aggregations on stock_ins
    create_if_not_exists index(:stock_ins, [:product_id, :tenant_id],
                           name: :stock_ins_product_tenant_index
                         )

    # Index for product-based aggregations on stock_outs
    create_if_not_exists index(:stock_outs, [:product_id, :tenant_id],
                           name: :stock_outs_product_tenant_index
                         )
  end
end
