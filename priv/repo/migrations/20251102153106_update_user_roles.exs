defmodule RiceMill.Repo.Migrations.UpdateUserRoles do
  use Ecto.Migration

  def up do
    # Update existing tenant_user roles to company_admin
    execute "UPDATE users SET role = 'company_admin' WHERE role = 'tenant_user'"

    # Add index on role for better query performance
    create index(:users, [:role])
  end

  def down do
    # Revert company_admin roles back to tenant_user
    execute "UPDATE users SET role = 'tenant_user' WHERE role = 'company_admin'"

    drop index(:users, [:role])
  end
end
