defmodule RiceMill.Dashboard.DashboardPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dashboard_preferences" do
    field :user_id, :id
    field :widget_order, {:array, :string}, default: []
    field :hidden_widgets, {:array, :string}, default: []
    field :default_time_period, :string, default: "this_month"

    timestamps()
  end

  @doc false
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:user_id, :widget_order, :hidden_widgets, :default_time_period])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end
