defmodule RiceMill.Repo.Migrations.AddDashboardQueryOptimizationIndexes do
  use Ecto.Migration

  def change do
    # Add DESC ordering indexes for date-based queries that need recent data first
    # These indexes improve performance for dashboard queries that order by date DESC

    # Index for stock_ins with date DESC ordering
    # Using raw SQL to specify DESC ordering on the date column
    execute(
      """
      CREATE INDEX IF NOT EXISTS stock_ins_tenant_date_desc_index
      ON stock_ins (tenant_id ASC, date DESC)
      """,
      "DROP INDEX IF EXISTS stock_ins_tenant_date_desc_index"
    )

    # Index for stock_outs with date DESC ordering
    execute(
      """
      CREATE INDEX IF NOT EXISTS stock_outs_tenant_date_desc_index
      ON stock_outs (tenant_id ASC, date DESC)
      """,
      "DROP INDEX IF EXISTS stock_outs_tenant_date_desc_index"
    )
  end
end
