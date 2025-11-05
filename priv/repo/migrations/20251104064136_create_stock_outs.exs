defmodule RiceMill.Repo.Migrations.CreateStockOuts do
  use Ecto.Migration

  def change do
    create table(:stock_outs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :product_id, references(:products, on_delete: :restrict, type: :binary_id), null: false
      add :date, :date, null: false
      add :customer_name, :string, null: false
      add :customer_contact, :string, null: false
      add :vehicle_number, :string
      add :num_of_bags, :integer, null: false
      add :net_weight_per_bag_kg, :decimal, precision: 10, scale: 3, null: false
      add :total_quintals, :decimal, precision: 10, scale: 3, null: false
      add :price_per_quintal, :decimal, precision: 10, scale: 2, null: false
      add :total_price, :decimal, precision: 12, scale: 2, null: false

      timestamps()
    end

    create index(:stock_outs, [:tenant_id])
    create index(:stock_outs, [:product_id])
    create index(:stock_outs, [:date])
    create index(:stock_outs, [:tenant_id, :date])
  end
end
