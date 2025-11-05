defmodule RiceMill.Accounts.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :changes, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :user, RiceMill.Accounts.User, type: :id
    belongs_to :tenant, RiceMill.Accounts.Tenant, type: :binary_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Creates a changeset for an audit log entry.
  """
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :user_id,
      :tenant_id,
      :action,
      :resource_type,
      :resource_id,
      :changes,
      :ip_address,
      :user_agent
    ])
    |> validate_required([:action])
    |> validate_length(:action, max: 255)
    |> validate_length(:resource_type, max: 255)
    |> validate_length(:ip_address, max: 45)
    |> validate_ip_format()
  end

  defp validate_ip_format(changeset) do
    case get_change(changeset, :ip_address) do
      nil ->
        changeset

      ip_address ->
        if valid_ip_format?(ip_address) do
          changeset
        else
          add_error(changeset, :ip_address, "must be a valid IP address")
        end
    end
  end

  defp valid_ip_format?(ip) when is_binary(ip) do
    # Simple IPv4 and IPv6 validation
    ipv4_regex =
      ~r/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/

    ipv6_regex =
      ~r/^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/

    String.match?(ip, ipv4_regex) or String.match?(ip, ipv6_regex)
  end

  defp valid_ip_format?(_), do: false
end
