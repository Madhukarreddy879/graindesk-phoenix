defmodule RiceMill.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :nilify_all, type: :id)
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :nilify_all)
      add :action, :string, null: false
      add :resource_type, :string
      add :resource_id, :binary_id
      add :changes, :map
      add :ip_address, :string
      add :user_agent, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:tenant_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:inserted_at])
    create index(:audit_logs, [:tenant_id, :inserted_at])
  end
end
