defmodule RiceMill.Repo.Migrations.ExtendUsersTable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string
      add :contact_phone, :string
      add :status, :string, default: "active", null: false
      add :last_login_at, :utc_datetime
      add :password_reset_required, :boolean, default: false, null: false
    end

    create index(:users, [:status])
    create index(:users, [:last_login_at])
  end
end
