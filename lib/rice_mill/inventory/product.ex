defmodule RiceMill.Inventory.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :name, :string
    field :sku, :string
    field :category, :string, default: "Paddy"
    field :unit, :string, default: "quintal"
    field :price_per_quintal, :decimal

    belongs_to :tenant, RiceMill.Accounts.Tenant

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:tenant_id, :name, :sku, :category, :unit, :price_per_quintal])
    |> validate_required([:tenant_id, :name, :sku, :price_per_quintal])
    |> validate_length(:name, max: 255)
    |> validate_number(:price_per_quintal, greater_than: 0)
    |> put_default_category()
    |> put_default_unit()
    |> unique_constraint([:tenant_id, :sku], name: :products_tenant_id_sku_index)
  end

  @doc false
  def update_changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :sku, :unit, :price_per_quintal])
    |> validate_required([:name, :sku, :price_per_quintal])
    |> validate_length(:name, max: 255)
    |> validate_number(:price_per_quintal, greater_than: 0)
    |> unique_constraint([:tenant_id, :sku], name: :products_tenant_id_sku_index)
  end

  defp put_default_category(changeset) do
    case get_field(changeset, :category) do
      nil -> put_change(changeset, :category, "Paddy")
      _ -> changeset
    end
  end

  defp put_default_unit(changeset) do
    case get_field(changeset, :unit) do
      nil -> put_change(changeset, :unit, "quintal")
      _ -> changeset
    end
  end
end
