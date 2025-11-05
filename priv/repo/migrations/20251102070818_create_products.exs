defmodule RiceMill.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :sku, :string, null: false
      add :category, :string, default: "Paddy", null: false
      add :unit, :string, default: "quintal", null: false
      add :price_per_quintal, :decimal, precision: 10, scale: 2, null: false

      timestamps()
    end

    create index(:products, [:tenant_id])
    create unique_index(:products, [:tenant_id, :sku])
  end
end
