defmodule RiceMill.Repo.Migrations.AddTenantAndRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict)
      add :role, :string, null: false, default: "tenant_user"
    end

    create index(:users, [:tenant_id])
  end
end
