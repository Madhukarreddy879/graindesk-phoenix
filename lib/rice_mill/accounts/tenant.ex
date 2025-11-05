defmodule RiceMill.Accounts.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :active, :boolean, default: true
    field :contact_email, :string
    field :contact_phone, :string
    field :settings, :map, default: %{}

    # Virtual fields for settings form
    field :default_unit, :string, virtual: true
    field :timezone, :string, virtual: true
    field :date_format, :string, virtual: true

    has_many :users, RiceMill.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug, :active, :contact_email, :contact_phone, :settings])
    |> validate_required([:name, :slug])
    |> validate_length(:name, max: 255)
    |> validate_length(:slug, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> validate_contact_email()
    |> validate_contact_phone()
    |> unique_constraint(:slug)
  end

  defp validate_contact_email(changeset) do
    changeset
    |> validate_format(:contact_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:contact_email, max: 160)
  end

  defp validate_contact_phone(changeset) do
    changeset
    |> validate_length(:contact_phone, max: 20)
  end
end
