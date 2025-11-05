defmodule RiceMill.Repo.Migrations.CreateStockIns do
  use Ecto.Migration

  def change do
    create table(:stock_ins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :binary_id, on_delete: :restrict), null: false
      add :date, :date, null: false
      add :farmer_name, :string, null: false
      add :farmer_contact, :string, null: false
      add :vehicle_number, :string, null: false
      add :num_of_bags, :integer, null: false
      add :net_weight_per_bag_kg, :decimal, precision: 8, scale: 2, null: false
      add :total_quintals, :decimal, precision: 10, scale: 3, null: false
      add :price_per_quintal, :decimal, precision: 10, scale: 2, null: false
      add :total_price, :decimal, precision: 12, scale: 2, null: false

      timestamps()
    end

    create index(:stock_ins, [:tenant_id])
    create index(:stock_ins, [:product_id])
    create index(:stock_ins, [:date])
    create index(:stock_ins, [:farmer_name])
  end
end
