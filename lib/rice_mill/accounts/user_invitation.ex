defmodule RiceMill.Accounts.UserInvitation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_invitations" do
    field :email, :string
    field :role, Ecto.Enum, values: [:operator, :viewer]
    field :token, :string
    field :status, Ecto.Enum, values: [:pending, :accepted, :expired], default: :pending
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime

    belongs_to :tenant, RiceMill.Accounts.Tenant, type: :binary_id
    belongs_to :invited_by, RiceMill.Accounts.User, type: :id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a user invitation.
  """
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [
      :email,
      :role,
      :tenant_id,
      :invited_by_id,
      :token,
      :expires_at,
      :status,
      :accepted_at
    ])
    |> validate_required([:email, :role, :tenant_id, :invited_by_id, :token, :expires_at])
    |> validate_email()
    |> validate_role()
    |> validate_status()
    |> unique_constraint(:token)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
  end

  defp validate_role(changeset) do
    changeset
    |> validate_inclusion(:role, [:operator, :viewer])
  end

  defp validate_status(changeset) do
    changeset
    |> validate_inclusion(:status, [:pending, :accepted, :expired])
  end

  @doc """
  Generates a secure random token for the invitation.
  """
  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc """
  Calculates the expiration datetime (7 days from now by default).
  """
  def calculate_expires_at(days \\ 7) do
    DateTime.utc_now() |> DateTime.add(days, :day)
  end
end
