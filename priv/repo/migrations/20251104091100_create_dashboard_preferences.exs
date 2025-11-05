defmodule RiceMill.Repo.Migrations.CreateDashboardPreferences do
  use Ecto.Migration

  def change do
    create table(:dashboard_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :widget_order, {:array, :text}, default: []
      add :hidden_widgets, {:array, :text}, default: []
      add :default_time_period, :string, default: "this_month"

      timestamps()
    end

    create unique_index(:dashboard_preferences, [:user_id])
  end
end
