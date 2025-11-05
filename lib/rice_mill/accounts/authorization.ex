defmodule RiceMill.Accounts.Authorization do
  @moduledoc """
  Centralized authorization logic for role-based access control.

  This module provides functions to check permissions based on user roles and resources.
  It implements a hierarchical role-based access control (RBAC) model with four roles:
  - super_admin: System-wide access to all features
  - company_admin: Tenant-scoped admin with user management capabilities
  - operator: Can create/edit inventory within their tenant
  - viewer: Read-only access to reports and data
  """

  alias RiceMill.Accounts.{User, Scope}
  alias RiceMill.Accounts.Tenant

  @doc """
  Checks if a user with the given scope can perform the specified action on a resource.

  ## Examples

      iex> can?(scope, :manage_users, %{tenant_id: "123"})
      true

      iex> can?(scope, :manage_tenants, nil)
      false
  """
  def can?(%Scope{user: nil}, _action, _resource), do: false

  def can?(%Scope{user: %User{role: :super_admin}}, _action, _resource), do: true

  def can?(%Scope{user: %User{role: :company_admin, tenant_id: user_tenant_id}}, action, resource)
      when not is_nil(user_tenant_id) do
    case action do
      :manage_users when is_map(resource) ->
        Map.get(resource, :tenant_id) == user_tenant_id

      :view_audit_logs when is_map(resource) ->
        Map.get(resource, :tenant_id) == user_tenant_id

      :manage_inventory ->
        true

      :view_reports ->
        true

      :manage_tenant_settings ->
        true

      _ ->
        false
    end
  end

  def can?(%Scope{user: %User{role: :operator, tenant_id: user_tenant_id}}, action, resource)
      when not is_nil(user_tenant_id) do
    case action do
      :manage_inventory ->
        same_tenant?(%Scope{user: %User{role: :operator, tenant_id: user_tenant_id}}, resource)

      :view_reports ->
        same_tenant?(%Scope{user: %User{role: :operator, tenant_id: user_tenant_id}}, resource)

      _ ->
        false
    end
  end

  def can?(%Scope{user: %User{role: :viewer, tenant_id: user_tenant_id}}, action, resource)
      when not is_nil(user_tenant_id) do
    case action do
      :view_reports ->
        same_tenant?(%Scope{user: %User{role: :viewer, tenant_id: user_tenant_id}}, resource)

      _ ->
        false
    end
  end

  def can?(_scope, _action, _resource), do: false

  @doc """
  Checks if the user has one of the specified roles.

  ## Examples

      iex> has_role?(scope, [:super_admin, :company_admin])
      true

      iex> has_role?(scope, [:operator])
      false
  """
  def has_role?(%Scope{user: nil}, _roles), do: false
  def has_role?(%Scope{user: %User{role: role}}, roles) when is_list(roles), do: role in roles
  def has_role?(%Scope{user: %User{role: role}}, role), do: true
  def has_role?(_scope, _role), do: false

  @doc """
  Checks if the user is a super admin.

  ## Examples

      iex> super_admin?(scope)
      true
  """
  def super_admin?(%Scope{user: %User{role: :super_admin}}), do: true
  def super_admin?(_scope), do: false

  @doc """
  Checks if the user is a company admin.

  ## Examples

      iex> company_admin?(scope)
      true
  """
  def company_admin?(%Scope{user: %User{role: :company_admin}}), do: true
  def company_admin?(_scope), do: false

  @doc """
  Checks if the user and resource belong to the same tenant.

  ## Examples

      iex> same_tenant?(scope, %{tenant_id: "123"})
      true

      iex> same_tenant?(scope, %User{tenant_id: "123"})
      true
  """
  def same_tenant?(%Scope{user: nil}, _resource), do: false

  def same_tenant?(%Scope{user: %User{tenant_id: user_tenant_id}}, resource) do
    resource_tenant_id = get_tenant_id(resource)
    user_tenant_id == resource_tenant_id
  end

  @doc """
  Checks if the user can manage users within a tenant.

  ## Examples

      iex> can_manage_users?(scope, "123")
      true
  """
  def can_manage_users?(%Scope{user: %User{role: :super_admin}}, _tenant_id), do: true

  def can_manage_users?(
        %Scope{user: %User{role: :company_admin, tenant_id: user_tenant_id}},
        tenant_id
      ),
      do: user_tenant_id == tenant_id

  def can_manage_users?(_scope, _tenant_id), do: false

  @doc """
  Checks if the user can manage tenants (create, update, delete).

  ## Examples

      iex> can_manage_tenants?(scope)
      true
  """
  def can_manage_tenants?(%Scope{user: %User{role: :super_admin}}), do: true
  def can_manage_tenants?(_scope), do: false

  @doc """
  Checks if the user can view audit logs for a tenant.

  ## Examples

      iex> can_view_audit_logs?(scope, "123")
      true
  """
  def can_view_audit_logs?(%Scope{user: %User{role: :super_admin}}, _tenant_id), do: true

  def can_view_audit_logs?(
        %Scope{user: %User{role: :company_admin, tenant_id: user_tenant_id}},
        tenant_id
      ),
      do: user_tenant_id == tenant_id

  def can_view_audit_logs?(_scope, _tenant_id), do: false

  @doc """
  Checks if the user can manage inventory (products, stock-in entries).

  ## Examples

      iex> can_manage_inventory?(scope)
      true
  """
  def can_manage_inventory?(%Scope{user: %User{role: role}})
      when role in [:company_admin, :operator],
      do: true

  def can_manage_inventory?(_scope), do: false

  @doc """
  Checks if the user can view reports.

  ## Examples

      iex> can_view_reports?(scope)
      true
  """
  def can_view_reports?(%Scope{user: %User{role: role}})
      when role in [:company_admin, :operator, :viewer],
      do: true

  def can_view_reports?(_scope), do: false

  @doc """
  Authorizes the user to perform an action on a resource, raising an exception if unauthorized.

  ## Examples

      iex> authorize!(scope, :manage_users, %{tenant_id: "123"})
      :ok

      iex> authorize!(scope, :manage_tenants, nil)
      ** raise RuntimeError
  """
  def authorize!(scope, action, resource) do
    if can?(scope, action, resource) do
      :ok
    else
      raise "Unauthorized access: User #{get_user_id(scope)} attempted to #{action} on resource #{inspect(resource)}"
    end
  end

  # Helper functions

  defp get_tenant_id(%User{tenant_id: tenant_id}), do: tenant_id
  defp get_tenant_id(%Tenant{id: id}), do: id
  defp get_tenant_id(%{tenant_id: tenant_id}), do: tenant_id
  defp get_tenant_id(_), do: nil

  defp get_user_id(%Scope{user: %User{id: id}}), do: id
  defp get_user_id(_), do: "anonymous"
end
