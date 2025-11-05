defmodule RiceMill.Inventory.StockIn do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "stock_ins" do
    field :date, :date
    field :farmer_name, :string
    field :farmer_contact, :string
    field :vehicle_number, :string
    field :num_of_bags, :integer
    field :net_weight_per_bag_kg, :decimal
    field :total_quintals, :decimal
    field :price_per_quintal, :decimal
    field :total_price, :decimal

    belongs_to :tenant, RiceMill.Accounts.Tenant
    belongs_to :product, RiceMill.Inventory.Product

    timestamps()
  end

  @doc false
  def changeset(stock_in, attrs) do
    stock_in
    |> cast(attrs, [
      :tenant_id,
      :product_id,
      :date,
      :farmer_name,
      :farmer_contact,
      :vehicle_number,
      :num_of_bags,
      :net_weight_per_bag_kg,
      :price_per_quintal
    ])
    |> validate_required([
      :tenant_id,
      :product_id,
      :date,
      :farmer_name,
      :farmer_contact,
      :vehicle_number,
      :num_of_bags,
      :net_weight_per_bag_kg,
      :price_per_quintal
    ])
    |> validate_length(:farmer_name, max: 255)
    |> validate_length(:farmer_contact, max: 20)
    |> validate_length(:vehicle_number, max: 50)
    |> validate_number(:num_of_bags, greater_than: 0)
    |> validate_number(:net_weight_per_bag_kg, greater_than: 0)
    |> validate_number(:price_per_quintal, greater_than: 0)
    |> validate_date_not_future()
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:tenant_id)
  end

  defp validate_date_not_future(changeset) do
    case get_field(changeset, :date) do
      nil ->
        changeset

      date ->
        if Date.compare(date, Date.utc_today()) == :gt do
          add_error(changeset, :date, "cannot be in the future")
        else
          changeset
        end
    end
  end
end
