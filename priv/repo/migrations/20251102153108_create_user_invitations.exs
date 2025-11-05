defmodule RiceMill.Repo.Migrations.CreateUserInvitations do
  use Ecto.Migration

  def change do
    create table(:user_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :role, :string, null: false
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :invited_by_id, references(:users, on_delete: :nilify_all), null: false
      add :status, :string, default: "pending", null: false
      add :expires_at, :utc_datetime, null: false
      add :accepted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_invitations, [:token])
    create index(:user_invitations, [:tenant_id])
    create index(:user_invitations, [:email])
    create index(:user_invitations, [:status])
    create index(:user_invitations, [:expires_at])
  end
end
