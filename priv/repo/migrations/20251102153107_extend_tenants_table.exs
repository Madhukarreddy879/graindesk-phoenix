defmodule RiceMill.Repo.Migrations.ExtendTenantsTable do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :contact_email, :string
      add :contact_phone, :string
      add :settings, :map, default: %{}
    end
  end
end
