defmodule RiceMill.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias RiceMill.Repo

  alias RiceMill.Accounts.{User, UserToken, UserNotifier, Tenant, UserInvitation, AuditLog}

  ## Tenant functions

  @doc """
  Returns the list of tenants.

  ## Examples

      iex> list_tenants()
      [%Tenant{}, ...]

  """
  def list_tenants do
    Repo.all(Tenant)
  end

  @doc """
  Gets a single tenant.

  Raises `Ecto.NoResultsError` if the Tenant does not exist.

  ## Examples

      iex> get_tenant!(123)
      %Tenant{}

      iex> get_tenant!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tenant!(id), do: Repo.get!(Tenant, id)

  @doc """
  Creates a tenant.

  ## Examples

      iex> create_tenant(%{field: value})
      {:ok, %Tenant{}}

      iex> create_tenant(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tenant(attrs \\ %{}) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tenant.

  ## Examples

      iex> update_tenant(tenant, %{field: new_value})
      {:ok, %Tenant{}}

      iex> update_tenant(tenant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tenant(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tenant.

  ## Examples

      iex> delete_tenant(tenant)
      {:ok, %Tenant{}}

      iex> delete_tenant(tenant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tenant(%Tenant{} = tenant) do
    Repo.delete(tenant)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tenant changes.

  ## Examples

      iex> change_tenant(tenant)
      %Ecto.Changeset{data: %Tenant{}}

  """
  def change_tenant(%Tenant{} = tenant, attrs \\ %{}) do
    Tenant.changeset(tenant, attrs)
  end

  ## Tenant scoping helpers

  @doc """
  Scopes a query to a specific tenant.

  ## Examples

      iex> scope_to_tenant(query, tenant_id)
      #Ecto.Query<...>

  """
  def scope_to_tenant(query, nil), do: query

  def scope_to_tenant(query, tenant_id) do
    from(q in query, where: q.tenant_id == ^tenant_id)
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    case %User{}
         |> User.email_changeset(attrs)
         |> Repo.insert() do
      {:ok, user} -> {:ok, Repo.preload(user, :tenant)}
      error -> error
    end
  end

  @doc """
  Updates the last login timestamp for a user.

  ## Examples

      iex> update_last_login(user)
      {:ok, %User{}}

      iex> update_last_login(nil)
      {:error, :user_not_found}

  """
  def update_last_login(nil), do: {:error, :user_not_found}

  def update_last_login(%User{} = user) do
    user
    |> User.email_changeset(%{last_login_at: DateTime.utc_now()})
    |> Repo.update()
  end

  ## User Management Functions

  @doc """
  Lists users with scope-based filtering.

  Super admins can see all users across all tenants.
  Company admins can only see users in their tenant.

  ## Examples

      iex> list_users(scope)
      [%User{}, ...]

      iex> list_users(scope, %{role: :operator})
      [%User{role: :operator}, ...]

  """
  def list_users(scope, filters \\ %{})

  def list_users(%RiceMill.Accounts.Scope{user: %User{role: :super_admin}}, filters) do
    query = from(u in User, order_by: [desc: u.inserted_at])

    query = apply_user_filters(query, filters)

    Repo.all(query) |> Repo.preload(:tenant)
  end

  def list_users(
        %RiceMill.Accounts.Scope{user: %User{role: :company_admin, tenant_id: tenant_id}},
        filters
      ) do
    list_users_for_tenant(tenant_id, filters)
  end

  def list_users(_scope, _filters), do: []

  @doc """
  Lists users for a specific tenant with optional filtering.

  ## Examples

      iex> list_users_for_tenant(tenant_id)
      [%User{}, ...]

      iex> list_users_for_tenant(tenant_id, %{status: :active})
      [%User{status: :active}, ...]

  """
  def list_users_for_tenant(tenant_id, filters \\ %{}) do
    query =
      from(u in User,
        where: u.tenant_id == ^tenant_id,
        order_by: [desc: u.inserted_at]
      )

    query = apply_user_filters(query, filters)

    Repo.all(query) |> Repo.preload(:tenant)
  end

  defp apply_user_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:role, role}, query ->
        from(u in query, where: u.role == ^role)

      {:status, status}, query ->
        from(u in query, where: u.status == ^status)

      {:email, email}, query ->
        from(u in query, where: ilike(u.email, ^"%#{email}%"))

      {:tenant_id, tenant_id}, query ->
        from(u in query, where: u.tenant_id == ^tenant_id)

      _, query ->
        query
    end)
  end

  @doc """
  Gets a single user with authorization check.

  Super admins can get any user.
  Company admins can only get users in their tenant.

  ## Examples

      iex> get_user!(id, scope)
      %User{}

      iex> get_user!(id, unauthorized_scope)
      ** (RuntimeError)

  """
  def get_user!(id, %RiceMill.Accounts.Scope{user: %User{role: :super_admin}}) do
    Repo.get!(User, id) |> Repo.preload(:tenant)
  end

  def get_user!(id, %RiceMill.Accounts.Scope{
        user: %User{role: :company_admin, tenant_id: tenant_id}
      }) do
    user = Repo.get!(User, id) |> Repo.preload(:tenant)

    if user.tenant_id == tenant_id do
      user
    else
      raise "Unauthorized: Cannot access user from different tenant"
    end
  end

  def get_user!(id, %RiceMill.Accounts.Scope{user: %User{id: user_id}}) when id == user_id do
    Repo.get!(User, id) |> Repo.preload(:tenant)
  end

  def get_user!(_id, _scope) do
    raise "Unauthorized: Cannot access user"
  end

  @doc """
  Creates a user with authorization and audit logging.

  ## Examples

      iex> create_user(%{email: "user@example.com", role: :operator}, scope)
      {:ok, %User{}}

      iex> create_user(%{email: "invalid"}, scope)
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs, %RiceMill.Accounts.Scope{user: creator} = _scope) do
    start_time = System.monotonic_time()

    # Authorization check
    tenant_id = Map.get(attrs, :tenant_id) || Map.get(attrs, "tenant_id")

    result = cond do
      creator.role == :super_admin ->
        # Super admin can create users in any tenant
        do_create_user(attrs, creator)

      creator.role == :company_admin && tenant_id == creator.tenant_id ->
        # Company admin can only create users in their own tenant
        # Prevent creating super_admin or company_admin roles
        role = Map.get(attrs, :role) || Map.get(attrs, "role")

        if role in [:super_admin, :company_admin, "super_admin", "company_admin"] do
          {:error, :unauthorized_role}
        else
          do_create_user(attrs, creator)
        end

      true ->
        {:error, :unauthorized}
    end

    # Emit telemetry event
    duration = System.monotonic_time() - start_time
    metadata = %{
      creator_id: creator.id,
      creator_role: creator.role,
      tenant_id: tenant_id,
      success: match?({:ok, _}, result)
    }
    :telemetry.execute([:rice_mill, :accounts, :user, :create], %{duration: duration}, metadata)

    result
  end

  @doc false
  # Internal function to create a user after authorization checks.
  # Handles audit logging and welcome email notifications.
  defp do_create_user(attrs, creator) do
    # Set default status to active if not provided
    attrs = Map.put_new(attrs, :status, :active)

    Repo.transaction(fn ->
      with {:ok, user} <- register_user(attrs) do
        # Log the user creation
        case log_action(creator, "user.created", %{
          resource_type: "User",
          resource_id: user.id,
          changes: %{
            email: user.email,
            role: user.role,
            tenant_id: user.tenant_id
          }
        }) do
          {:ok, _audit_log} -> :ok
          {:error, reason} ->
            require Logger
            Logger.warning("Failed to create audit log for user creation: #{inspect(reason)}")
        end

        # Send welcome email (non-critical, log errors but don't fail)
        try do
          UserNotifier.deliver_welcome_email(user, creator)
        rescue
          e ->
            require Logger
            Logger.error("Failed to send welcome email: #{Exception.message(e)}")
        end

        {:ok, user}
      end
    end)
  end

  @doc """
  Updates a user with authorization and audit logging.

  ## Examples

      iex> update_user(user, %{name: "New Name"}, scope)
      {:ok, %User{}}

      iex> update_user(user, %{email: "invalid"}, scope)
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs, %RiceMill.Accounts.Scope{user: updater} = _scope) do
    # Authorization check
    cond do
      updater.role == :super_admin ->
        # Super admin can update any user
        do_update_user(user, attrs, updater)

      updater.role == :company_admin && user.tenant_id == updater.tenant_id ->
        # Company admin can update users in their tenant
        # Prevent changing role to super_admin or company_admin
        role = Map.get(attrs, :role) || Map.get(attrs, "role")

        if role in [:super_admin, :company_admin, "super_admin", "company_admin"] do
          {:error, :unauthorized_role}
        else
          do_update_user(user, attrs, updater)
        end

      updater.id == user.id ->
        # Users can update their own profile (limited fields)
        allowed_attrs = Map.take(attrs, [:name, :contact_phone, "name", "contact_phone"])
        do_update_user(user, allowed_attrs, updater)

      true ->
        {:error, :unauthorized}
    end
  end

  @doc false
  # Internal function to update a user after authorization checks.
  # Tracks changes in audit log.
  defp do_update_user(user, attrs, updater) do
    old_values = Map.take(user, [:email, :role, :status, :name, :contact_phone])

    Repo.transaction(fn ->
      with {:ok, updated_user} <-
             user
             |> User.email_changeset(attrs)
             |> Repo.update() do
        # Log the user update
        log_action(updater, "user.updated", %{
          resource_type: "User",
          resource_id: user.id,
          changes: %{
            before: old_values,
            after: Map.take(updated_user, [:email, :role, :status, :name, :contact_phone])
          }
        })

        {:ok, updated_user}
      end
    end)
  end

  @doc """
  Deletes a user with authorization and audit logging.

  ## Examples

      iex> delete_user(user, scope)
      {:ok, %User{}}

      iex> delete_user(user, unauthorized_scope)
      {:error, :unauthorized}

  """
  def delete_user(%User{} = user, %RiceMill.Accounts.Scope{user: deleter}) do
    # Authorization check
    cond do
      deleter.role == :super_admin ->
        # Super admin can delete any user
        do_delete_user(user, deleter)

      deleter.role == :company_admin && user.tenant_id == deleter.tenant_id ->
        # Company admin can delete users in their tenant (except themselves)
        if user.id == deleter.id do
          {:error, :cannot_delete_self}
        else
          do_delete_user(user, deleter)
        end

      true ->
        {:error, :unauthorized}
    end
  end

  @doc false
  # Internal function to delete a user after authorization checks.
  # Logs the deletion in audit trail.
  defp do_delete_user(user, deleter) do
    Repo.transaction(fn ->
      with {:ok, deleted_user} <- Repo.delete(user) do
        # Log the user deletion
        log_action(deleter, "user.deleted", %{
          resource_type: "User",
          resource_id: user.id,
          changes: %{
            email: user.email,
            role: user.role
          }
        })

        {:ok, deleted_user}
      end
    end)
  end

  @doc """
  Deactivates a user account.

  ## Examples

      iex> deactivate_user(user, scope)
      {:ok, %User{status: :inactive}}

      iex> deactivate_user(user, unauthorized_scope)
      {:error, :unauthorized}

  """
  def deactivate_user(%User{} = user, %RiceMill.Accounts.Scope{user: deactivator}) do
    # Authorization check
    cond do
      deactivator.role == :super_admin ->
        do_deactivate_user(user, deactivator)

      deactivator.role == :company_admin && user.tenant_id == deactivator.tenant_id ->
        if user.id == deactivator.id do
          {:error, :cannot_deactivate_self}
        else
          do_deactivate_user(user, deactivator)
        end

      true ->
        {:error, :unauthorized}
    end
  end

  @doc false
  # Internal function to deactivate a user after authorization checks.
  # Sets status to inactive and logs the action.
  defp do_deactivate_user(user, deactivator) do
    Repo.transaction(fn ->
      with {:ok, updated_user} <-
             user
             |> User.email_changeset(%{status: :inactive})
             |> Repo.update() do
        # Log the deactivation
        log_action(deactivator, "user.deactivated", %{
          resource_type: "User",
          resource_id: user.id,
          changes: %{
            status: %{from: :active, to: :inactive}
          }
        })

        {:ok, updated_user}
      end
    end)
  end

  @doc """
  Activates a user account.

  ## Examples

      iex> activate_user(user, scope)
      {:ok, %User{status: :active}}

      iex> activate_user(user, unauthorized_scope)
      {:error, :unauthorized}

  """
  def activate_user(%User{} = user, %RiceMill.Accounts.Scope{user: activator}) do
    # Authorization check
    cond do
      activator.role == :super_admin ->
        do_activate_user(user, activator)

      activator.role == :company_admin && user.tenant_id == activator.tenant_id ->
        do_activate_user(user, activator)

      true ->
        {:error, :unauthorized}
    end
  end

  @doc false
  # Internal function to activate a user after authorization checks.
  # Sets status to active and logs the action.
  defp do_activate_user(user, activator) do
    Repo.transaction(fn ->
      with {:ok, updated_user} <-
             user
             |> User.email_changeset(%{status: :active})
             |> Repo.update() do
        # Log the activation
        log_action(activator, "user.activated", %{
          resource_type: "User",
          resource_id: user.id,
          changes: %{
            status: %{from: :inactive, to: :active}
          }
        })

        {:ok, updated_user}
      end
    end)
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing user data.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing user email.

  See `RiceMill.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transaction(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `RiceMill.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Also clears the password_reset_required flag if it was set.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs, current_token \\ nil) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> Ecto.Changeset.put_change(:password_reset_required, false)

    if current_token do
      update_user_and_delete_all_tokens_except(changeset, current_token)
    else
      update_user_and_delete_all_tokens(changeset)
    end
  end

  @doc """
  Resets a user's password to a temporary password and optionally sends an email.

  Returns a tuple with the updated user and the temporary password.

  ## Examples

      iex> reset_user_password(user, send_email: true)
      {:ok, {%User{}, "temp_password_123"}}

      iex> reset_user_password(user, send_email: false)
      {:ok, {%User{}, "temp_password_456"}}

  """
  def reset_user_password(user, opts \\ []) do
    send_email = Keyword.get(opts, :send_email, true)
    temp_password = generate_temporary_password()

    attrs = %{
      password: temp_password,
      password_reset_required: true
    }

    case update_user_password(user, attrs) do
      {:ok, {updated_user, _tokens}} ->
        # Log the password reset action
        log_action(user, "password.reset", %{
          resource_type: "User",
          resource_id: user.id
        })

        if send_email do
          UserNotifier.deliver_password_reset(updated_user, temp_password)
        end

        {:ok, {updated_user, temp_password}}

      error ->
        error
    end
  end

  @doc """
  Sets the password_reset_required flag for a user.

  Returns {:ok, user} on success or {:error, changeset} on failure.

  ## Examples

      iex> require_password_change(user)
      {:ok, %User{}}

  """
  def require_password_change(user) do
    user
    |> User.email_changeset(%{password_reset_required: true})
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  @doc """
  Updates the session activity timestamp to track user activity.
  This is used to implement session timeout based on inactivity.
  """
  def update_session_activity(token) do
    query = UserToken.update_session_activity(token)
    Repo.update_all(query, [])
    :ok
  end

  @doc """
  Lists all active sessions for a user.
  Returns a list of session tokens with their creation and last activity times.
  """
  def list_user_sessions(user_id) do
    timeout_hours = Application.get_env(:rice_mill, :session_timeout_hours, 24)

    from(t in UserToken,
      where: t.user_id == ^user_id and t.context == "session",
      where: t.authenticated_at > ago(^timeout_hours, "hour"),
      order_by: [desc: t.authenticated_at],
      select: %{
        id: t.id,
        token: t.token,
        inserted_at: t.inserted_at,
        authenticated_at: t.authenticated_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Revokes a specific session token for a user.
  """
  def revoke_user_session(user_id, token) do
    Repo.delete_all(
      from(t in UserToken,
        where: t.user_id == ^user_id and t.token == ^token and t.context == "session"
      )
    )

    :ok
  end

  @doc """
  Invalidates all sessions for a user except the current one.
  This is typically called when a user changes their password.
  """
  def invalidate_all_sessions_except(user_id, current_token) do
    tokens_to_expire =
      from(t in UserToken,
        where: t.user_id == ^user_id and t.context == "session" and t.token != ^current_token,
        select: t
      )
      |> Repo.all()

    Repo.delete_all(
      from(t in UserToken,
        where: t.user_id == ^user_id and t.context == "session" and t.token != ^current_token
      )
    )

    # Broadcast session disconnection event via PubSub
    broadcast_session_disconnect(tokens_to_expire)

    :ok
  end

  @doc """
  Invalidates all sessions for a user.
  This is typically called when a user is deactivated or deleted.
  """
  def invalidate_all_sessions(user_id) do
    tokens_to_expire =
      from(t in UserToken,
        where: t.user_id == ^user_id and t.context == "session",
        select: t
      )
      |> Repo.all()

    Repo.delete_all(
      from(t in UserToken,
        where: t.user_id == ^user_id and t.context == "session"
      )
    )

    # Broadcast session disconnection event via PubSub
    broadcast_session_disconnect(tokens_to_expire)

    :ok
  end

  # Helper function to broadcast session disconnect events
  defp broadcast_session_disconnect(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      Phoenix.PubSub.broadcast(
        RiceMill.PubSub,
        "users_sessions:#{Base.url_encode64(token)}",
        :disconnect
      )
    end)
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transaction(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  defp update_user_and_delete_all_tokens_except(changeset, current_token) do
    Repo.transaction(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire =
          from(t in UserToken,
            where: t.user_id == ^user.id and t.token != ^current_token
          )
          |> Repo.all()

        Repo.delete_all(
          from(t in UserToken,
            where: t.user_id == ^user.id and t.token != ^current_token
          )
        )

        # Broadcast session disconnection event via PubSub (decoupled from Web layer)
        broadcast_session_disconnect(tokens_to_expire)

        # Log session invalidation
        log_action(user, "session.invalidated_all_except_current", %{
          resource_type: "Session",
          resource_id: user.id,
          changes: %{
            sessions_invalidated: length(tokens_to_expire)
          }
        })

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## User Invitation functions

  @doc """
  Creates a user invitation.

  ## Examples

      iex> create_invitation(%{email: "user@example.com", role: :operator, tenant_id: tenant_id}, invited_by_user)
      {:ok, %UserInvitation{}}

      iex> create_invitation(%{email: "invalid"}, invited_by_user)
      {:error, %Ecto.Changeset{}}

  """
  def create_invitation(attrs, invited_by_user) when is_struct(invited_by_user, User) do
    token = UserInvitation.generate_token()
    expires_at = UserInvitation.calculate_expires_at()

    attrs =
      attrs
      |> Map.put(:token, token)
      |> Map.put(:expires_at, expires_at)
      |> Map.put(:invited_by_id, invited_by_user.id)

    %UserInvitation{}
    |> UserInvitation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a user invitation and sends the invitation email.

  ## Examples

      iex> create_invitation_and_send_email(%{email: "user@example.com", role: :operator, tenant_id: tenant_id}, invited_by_user, invitation_url_fun)
      {:ok, %UserInvitation{}}

      iex> create_invitation_and_send_email(%{email: "invalid"}, invited_by_user, invitation_url_fun)
      {:error, %Ecto.Changeset{}}

  """
  def create_invitation_and_send_email(attrs, invited_by_user, invitation_url_fun)
      when is_struct(invited_by_user, User) and is_function(invitation_url_fun, 1) do
    case create_invitation(attrs, invited_by_user) do
      {:ok, invitation} ->
        invitation_url = invitation_url_fun.(invitation.token)
        UserNotifier.deliver_user_invitation(invitation, invitation_url)
        {:ok, invitation}

      error ->
        error
    end
  end

  @doc """
  Gets a user invitation by token.

  Returns nil if the invitation does not exist.

  ## Examples

      iex> get_invitation_by_token("valid_token")
      %UserInvitation{}

      iex> get_invitation_by_token("invalid_token")
      nil

  """
  def get_invitation_by_token(token) when is_binary(token) do
    Repo.get_by(UserInvitation, token: token)
    |> Repo.preload([:tenant, :invited_by])
  end

  @doc """
  Accepts a user invitation and creates a user account.

  ## Examples

      iex> accept_invitation("valid_token", %{password: "secure_password", name: "John Doe"})
      {:ok, %User{}}

      iex> accept_invitation("expired_token", %{password: "secure_password"})
      {:error, :invitation_expired}

      iex> accept_invitation("invalid_token", %{password: "secure_password"})
      {:error, :invitation_not_found}

  """
  def accept_invitation(token, user_attrs) when is_binary(token) do
    case get_invitation_by_token(token) do
      nil ->
        {:error, :invitation_not_found}

      %UserInvitation{status: :accepted} ->
        {:error, :invitation_already_accepted}

      %UserInvitation{status: :expired} ->
        {:error, :invitation_expired}

      %UserInvitation{expires_at: expires_at} = invitation ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :gt do
          # Mark as expired
          invitation
          |> UserInvitation.changeset(%{status: :expired})
          |> Repo.update()

          {:error, :invitation_expired}
        else
          # Create user and mark invitation as accepted
          Repo.transaction(fn ->
            user_attrs =
              user_attrs
              |> Map.put(:email, invitation.email)
              |> Map.put(:role, invitation.role)
              |> Map.put(:tenant_id, invitation.tenant_id)
              |> Map.put(:status, :active)

            with {:ok, user} <- register_user(user_attrs),
                 {:ok, _invitation} <-
                   invitation
                   |> UserInvitation.changeset(%{
                     status: :accepted,
                     accepted_at: DateTime.utc_now()
                   })
                   |> Repo.update() do
              # Send welcome email
              UserNotifier.deliver_welcome_email(user)
              {:ok, user}
            end
          end)
        end
    end
  end

  @doc """
  Expires old pending invitations that have passed their expiration date.

  Returns the count of expired invitations.

  ## Examples

      iex> expire_old_invitations()
      {3, nil}

  """
  def expire_old_invitations do
    now = DateTime.utc_now()

    from(i in UserInvitation,
      where: i.status == :pending and i.expires_at < ^now
    )
    |> Repo.update_all(set: [status: :expired, updated_at: now])
  end

  ## Audit Log functions

  @doc """
  Creates an audit log entry.

  ## Examples

      iex> log_action(user, "user.create", %{resource_id: user_id, changes: %{name: "John"}})
      {:ok, %AuditLog{}}

      iex> log_action(user, "invalid_action", %{})
      {:error, %Ecto.Changeset{}}

  """
  def log_action(%User{} = user, action, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:tenant_id, user.tenant_id)
      |> Map.put(:action, action)

    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists audit logs with optional filters.

  ## Examples

      iex> list_audit_logs(tenant_id)
      [%AuditLog{}, ...]

      iex> list_audit_logs(tenant_id, %{action: "user.create", limit: 10})
      [%AuditLog{}, ...]

  """
  def list_audit_logs(tenant_id, opts \\ %{}) do
    query =
      from a in AuditLog,
        where: a.tenant_id == ^tenant_id,
        order_by: [desc: a.inserted_at]

    query =
      case opts do
        %{action: action} -> from(a in query, where: a.action == ^action)
        _ -> query
      end

    query =
      case opts do
        %{limit: limit} -> from(a in query, limit: ^limit)
        _ -> query
      end

    query =
      case opts do
        %{resource_type: resource_type} ->
          from(a in query, where: a.resource_type == ^resource_type)

        _ ->
          query
      end

    Repo.all(query)
  end

  @doc """
  Gets user activity audit logs.

  ## Examples

      iex> get_user_activity(user_id, tenant_id)
      [%AuditLog{}, ...]

      iex> get_user_activity(user_id, tenant_id, %{limit: 5})
      [%AuditLog{}, ...]

  """
  def get_user_activity(user_id, tenant_id, opts \\ %{}) do
    query =
      from a in AuditLog,
        where: a.user_id == ^user_id and a.tenant_id == ^tenant_id,
        order_by: [desc: a.inserted_at]

    query =
      case opts do
        %{limit: limit} -> from(a in query, limit: ^limit)
        _ -> query
      end

    Repo.all(query)
  end

  ## Tenant Management Functions

  @doc """
  Lists all tenants with user count and last activity statistics.

  ## Examples

      iex> list_tenants_with_stats()
      [%{tenant: %Tenant{}, user_count: 5, last_activity: ~U[2023-01-01 00:00:00Z]}, ...]

  """
  def list_tenants_with_stats do
    from(t in Tenant,
      left_join: u in User,
      on: u.tenant_id == t.id and u.status == :active,
      left_join: a in AuditLog,
      on: a.tenant_id == t.id,
      group_by: [t.id, t.name, t.slug, t.active, t.inserted_at],
      select: %{
        tenant: t,
        user_count: count(u.id, :distinct),
        last_activity: max(a.inserted_at)
      },
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Searches tenants with statistics by name or slug.

  ## Examples

      iex> search_tenants_with_stats("acme")
      [%{tenant: %Tenant{}, user_count: 5, last_activity: ~U[2023-01-01 00:00:00Z]}, ...]

      iex> search_tenants_with_stats("")
      [] # Returns empty list for empty search term

  """
  def search_tenants_with_stats(search_term) when search_term in ["", nil] do
    []
  end

  def search_tenants_with_stats(search_term) do
    search_pattern = "%#{search_term}%"

    from(t in Tenant,
      left_join: u in User,
      on: u.tenant_id == t.id and u.status == :active,
      left_join: a in AuditLog,
      on: a.tenant_id == t.id,
      where: ilike(t.name, ^search_pattern) or ilike(t.slug, ^search_pattern),
      group_by: [t.id, t.name, t.slug, t.active, t.inserted_at],
      select: %{
        tenant: t,
        user_count: count(u.id, :distinct),
        last_activity: max(a.inserted_at)
      },
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Counts total number of tenants.
  """
  def count_tenants do
    Repo.aggregate(Tenant, :count, :id)
  end

  @doc """
  Counts active tenants.
  """
  def count_active_tenants do
    from(t in Tenant, where: t.active == true)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts inactive tenants.
  """
  def count_inactive_tenants do
    from(t in Tenant, where: t.active == false)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts all users across all tenants.
  """
  def count_all_users do
    Repo.aggregate(User, :count, :id)
  end

  @doc """
  Lists recent tenants (most recently created).
  """
  def list_recent_tenants(limit \\ 5) do
    from(t in Tenant,
      order_by: [desc: t.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets a single tenant with detailed statistics and user information.

  ## Examples

      iex> get_tenant_with_stats!(tenant_id)
      %{
        tenant: %Tenant{},
        user_count: 5,
        active_users: 3,
        last_activity: ~U[2023-01-01 00:00:00Z],
        users: [%User{}, ...]
      }

  """
  def get_tenant_with_stats!(id) do
    tenant = get_tenant!(id)

    # Get total user count
    total_users =
      from(u in User,
        where: u.tenant_id == ^id,
        select: count(u.id)
      )
      |> Repo.one!()

    # Get active user count
    active_users =
      from(u in User,
        where: u.tenant_id == ^id and u.status == :active and not is_nil(u.confirmed_at),
        select: count(u.id)
      )
      |> Repo.one!()

    # Get last user activity
    last_user_activity =
      from(u in User,
        where: u.tenant_id == ^id,
        select: max(u.last_login_at)
      )
      |> Repo.one()

    users =
      from(u in User,
        where: u.tenant_id == ^id,
        order_by: [desc: u.inserted_at],
        limit: 10
      )
      |> Repo.all()

    last_audit_activity =
      from(a in AuditLog,
        where: a.tenant_id == ^id,
        select: max(a.inserted_at)
      )
      |> Repo.one()

    %{
      tenant: tenant,
      user_count: total_users,
      active_users: active_users,
      last_activity: max_date(last_user_activity, last_audit_activity),
      users: users
    }
  end

  @doc """
  Creates a tenant and admin user in a transaction.

  ## Examples

      iex> create_tenant_with_admin(%{name: "Acme Corp", slug: "acme-corp"}, "admin@acme.com", "Admin User")
      {:ok, %{tenant: %Tenant{}, admin_user: %User{}}}

      iex> create_tenant_with_admin(%{name: ""}, "admin@acme.com", "Admin User")
      {:error, :tenant_creation_failed, %Ecto.Changeset{}}

  """
  def create_tenant_with_admin(tenant_attrs, admin_email, admin_name, admin_password \\ nil) do
    Repo.transaction(fn ->
      with {:ok, tenant} <- create_tenant(tenant_attrs),
           {:ok, admin_user} <- create_admin_user(tenant, admin_email, admin_name, admin_password) do
        {:ok, %{tenant: tenant, admin_user: admin_user}}
      else
        {:error, changeset} ->
          {:error, :tenant_creation_failed, changeset}

        error ->
          error
      end
    end)
  end

  defp create_admin_user(tenant, email, name, password) do
    user_attrs = %{
      email: email,
      name: name,
      role: :company_admin,
      tenant_id: tenant.id,
      status: :active,
      confirmed_at: DateTime.utc_now()
    }

    password_to_use = password || generate_temporary_password()

    %User{}
    |> User.email_changeset(user_attrs)
    |> User.password_changeset(%{password: password_to_use})
    |> Repo.insert()
  end

  @doc """
  Updates a tenant with authorization check.

  ## Examples

      iex> update_tenant(tenant, current_user, %{name: "New Name"})
      {:ok, %Tenant{}}

      iex> update_tenant(tenant, unauthorized_user, %{name: "New Name"})
      {:error, :unauthorized}

  """
  def update_tenant(%Tenant{} = tenant, %User{} = current_user, attrs) do
    with :ok <- authorize_tenant_management(current_user, tenant.id) do
      update_tenant(tenant, attrs)
    end
  end

  @doc """
  Deactivates a tenant.

  ## Examples

      iex> deactivate_tenant(tenant, current_user)
      {:ok, %Tenant{active: false}}

      iex> deactivate_tenant(tenant, unauthorized_user)
      {:error, :unauthorized}

  """
  def deactivate_tenant(%Tenant{} = tenant, %User{} = current_user) do
    with :ok <- authorize_tenant_management(current_user, tenant.id) do
      update_tenant(tenant, %{active: false})
    end
  end

  @doc """
  Activates a tenant.

  ## Examples

      iex> activate_tenant(tenant, current_user)
      {:ok, %Tenant{active: true}}

      iex> activate_tenant(tenant, unauthorized_user)
      {:error, :unauthorized}

  """
  def activate_tenant(%Tenant{} = tenant, %User{} = current_user) do
    with :ok <- authorize_tenant_management(current_user, tenant.id) do
      update_tenant(tenant, %{active: true})
    end
  end

  @doc """
  Gets tenant settings.

  ## Examples

      iex> get_tenant_settings(tenant)
      %{default_unit: "kg", timezone: "UTC", date_format: "YYYY-MM-DD"}

  """
  def get_tenant_settings(%Tenant{} = tenant) do
    Map.get(tenant.settings, "default_settings", %{
      "default_unit" => "kg",
      "timezone" => "UTC",
      "date_format" => "YYYY-MM-DD"
    })
  end

  @doc """
  Updates tenant settings.

  ## Examples

      iex> update_tenant_settings(tenant, current_user, %{default_unit: "lbs"})
      {:ok, %Tenant{}}

      iex> update_tenant_settings(tenant, unauthorized_user, %{default_unit: "lbs"})
      {:error, :unauthorized}

  """
  def update_tenant_settings(%Tenant{} = tenant, %User{} = current_user, settings_attrs) do
    with :ok <- authorize_tenant_management(current_user, tenant.id) do
      updated_settings = Map.merge(get_tenant_settings(tenant), settings_attrs)

      update_tenant(tenant, %{
        settings: Map.put(tenant.settings || %{}, "default_settings", updated_settings)
      })
    end
  end

  @doc """
  Gets tenant activity metrics for monitoring.

  ## Examples

      iex> get_tenant_activity_metrics(tenant_id)
      %{
        total_users: 10,
        active_users: 8,
        inactive_users: 2,
        last_7_days_logins: 15,
        last_30_days_logins: 45,
        recent_activity: [%{action: "user.login", timestamp: ~U[2023-01-01 00:00:00Z]}, ...]
      }

  """
  def get_tenant_activity_metrics(tenant_id) do
    # User statistics
    total_users =
      from(u in User,
        where: u.tenant_id == ^tenant_id,
        select: count(u.id)
      )
      |> Repo.one!()

    active_users =
      from(u in User,
        where: u.tenant_id == ^tenant_id and u.status == :active and not is_nil(u.confirmed_at),
        select: count(u.id)
      )
      |> Repo.one!()

    inactive_users =
      from(u in User,
        where: u.tenant_id == ^tenant_id and (u.status == :inactive or is_nil(u.confirmed_at)),
        select: count(u.id)
      )
      |> Repo.one!()

    # Login activity for last 7 and 30 days
    now = DateTime.utc_now()
    seven_days_ago = DateTime.add(now, -7, :day)
    thirty_days_ago = DateTime.add(now, -30, :day)

    last_7_days_logins =
      from(a in AuditLog,
        where:
          a.tenant_id == ^tenant_id and a.action == "user.login" and
            a.inserted_at >= ^seven_days_ago,
        select: count(a.id)
      )
      |> Repo.one!()

    last_30_days_logins =
      from(a in AuditLog,
        where:
          a.tenant_id == ^tenant_id and a.action == "user.login" and
            a.inserted_at >= ^thirty_days_ago,
        select: count(a.id)
      )
      |> Repo.one!()

    # Recent activity (last 10 actions)
    recent_activity =
      from(a in AuditLog,
        where: a.tenant_id == ^tenant_id,
        order_by: [desc: a.inserted_at],
        limit: 10,
        select: {
          a.action,
          a.inserted_at,
          fragment("(SELECT email FROM users WHERE id = ?)", a.user_id)
        }
      )
      |> Repo.all()
      |> Enum.map(fn {action, timestamp, user_email} ->
        %{
          action: action,
          timestamp: timestamp,
          user_email: user_email
        }
      end)

    %{
      total_users: total_users,
      active_users: active_users,
      inactive_users: inactive_users,
      last_7_days_logins: last_7_days_logins,
      last_30_days_logins: last_30_days_logins,
      recent_activity: recent_activity
    }
  end

  ## Helper functions

  defp authorize_tenant_management(%User{role: :super_admin}, _tenant_id), do: :ok

  defp authorize_tenant_management(%User{role: :company_admin, tenant_id: tenant_id}, tenant_id),
    do: :ok

  defp authorize_tenant_management(_user, _tenant_id), do: {:error, :unauthorized}

  defp max_date(nil, nil), do: nil
  defp max_date(date1, nil), do: date1
  defp max_date(nil, date2), do: date2

  defp max_date(date1, date2) do
    if DateTime.compare(date1, date2) == :gt, do: date1, else: date2
  end

  defp generate_temporary_password do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> binary_part(0, 16)
  end

  ## CSV Bulk Import Functions

  @doc """
  Imports users from a CSV file with validation and transaction support.

  Returns {:ok, summary} on success or {:error, reason} on failure.
  The summary includes successful imports and any validation errors.

  ## Examples

      iex> import_users_from_csv(csv_content, tenant_id, current_user)
      {:ok, %{
        total_rows: 10,
        successful: 8,
        failed: 2,
        errors: [%{row: 3, email: "invalid", error: "Invalid email format"}],
        created_users: [%User{}, ...]
      }}

      iex> import_users_from_csv("invalid,csv,content", tenant_id, current_user)
      {:error, :invalid_csv_format}

  """
  def import_users_from_csv(csv_content, tenant_id, %User{} = current_user) do
    with {:ok, parsed_data} <- parse_csv_content(csv_content),
         {:ok, validated_data} <- validate_csv_import(parsed_data, tenant_id, current_user) do
      create_users_from_csv_data(validated_data, tenant_id, current_user)
    end
  end

  @doc """
  Validates CSV data before import, returning validation results.

  ## Examples

      iex> validate_csv_import(parsed_csv_data, tenant_id, current_user)
      {:ok, %{valid_rows: [...], invalid_rows: [...], total_rows: 10}}

      iex> validate_csv_import(invalid_data, tenant_id, current_user)
      {:error, :unauthorized_role}

  """
  def validate_csv_import(parsed_data, tenant_id, %User{} = current_user) do
    # Authorization check - only company admins and super admins can import users
    cond do
      current_user.role == :super_admin ->
        do_validate_csv_data(parsed_data, tenant_id)

      current_user.role == :company_admin && current_user.tenant_id == tenant_id ->
        do_validate_csv_data(parsed_data, tenant_id)

      true ->
        {:error, :unauthorized}
    end
  end

  ## CSV Parsing

  defp parse_csv_content(csv_content) when is_binary(csv_content) do
    try do
      # Define CSV parser with headers
      csv_module = NimbleCSV.RFC4180

      # Parse CSV content
      parsed_rows = csv_module.parse_string(csv_content, skip_headers: false)

      # Extract headers and data
      case parsed_rows do
        [] ->
          {:error, :empty_csv}

        [headers | data_rows] ->
          # Convert headers to strings and validate required columns
          headers = Enum.map(headers, &String.trim/1)

          with :ok <- validate_csv_headers(headers) do
            # Convert data rows to maps
            data_maps =
              Enum.map(data_rows, fn row ->
                Enum.zip(headers, Enum.map(row, &String.trim/1))
                |> Map.new()
              end)

            {:ok, data_maps}
          end
      end
    rescue
      _ -> {:error, :invalid_csv_format}
    end
  end

  defp parse_csv_content(_), do: {:error, :invalid_csv_content}

  defp validate_csv_headers(headers) do
    required_headers = ["email", "role"]
    missing_headers = required_headers -- headers

    if Enum.empty?(missing_headers) do
      :ok
    else
      {:error, {:missing_headers, missing_headers}}
    end
  end

  ## CSV Data Validation

  defp do_validate_csv_data(data_maps, tenant_id) do
    {valid_rows, invalid_rows} =
      data_maps
      # Add row numbers starting from 1
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {row_data, row_number}, {valid_acc, invalid_acc} ->
        case validate_csv_row(row_data, row_number, tenant_id) do
          {:ok, validated_row} ->
            {[validated_row | valid_acc], invalid_acc}

          {:error, error} ->
            error_details = %{
              row: row_number,
              email: Map.get(row_data, "email", ""),
              error: error
            }

            {valid_acc, [error_details | invalid_acc]}
        end
      end)

    result = %{
      valid_rows: Enum.reverse(valid_rows),
      invalid_rows: Enum.reverse(invalid_rows),
      total_rows: length(data_maps)
    }

    {:ok, result}
  end

  defp validate_csv_row(row_data, _row_number, tenant_id) do
    email = Map.get(row_data, "email", "") |> String.trim()
    role = Map.get(row_data, "role", "") |> String.trim() |> String.downcase()
    name = Map.get(row_data, "name", "") |> String.trim()
    contact_phone = Map.get(row_data, "contact_phone", "") |> String.trim()

    with :ok <- validate_email_format(email),
         :ok <- validate_email_uniqueness(email),
         :ok <- validate_role_for_import(role),
         :ok <- validate_name_length(name),
         :ok <- validate_contact_phone(contact_phone) do
      # Convert role string to atom
      role_atom = String.to_existing_atom(role)

      {:ok,
       %{
         email: email,
         role: role_atom,
         name: name,
         contact_phone: contact_phone,
         tenant_id: tenant_id,
         status: :active,
         password: generate_temporary_password(),
         password_reset_required: true
       }}
    end
  end

  defp validate_email_format(email) when email == "", do: {:error, "Email is required"}

  defp validate_email_format(email) do
    if email =~ ~r/^[^\s]+@[^\s]+$/ do
      :ok
    else
      {:error, "Invalid email format"}
    end
  end

  defp validate_email_uniqueness(email) do
    # Note: We still check here for better user feedback during validation,
    # but we rely on database unique constraint for actual enforcement
    # to prevent race conditions
    if get_user_by_email(email) do
      {:error, "Email already exists"}
    else
      :ok
    end
  end

  defp validate_role_for_import(role) when role in ["operator", "viewer"], do: :ok
  defp validate_role_for_import(""), do: {:error, "Role is required"}
  defp validate_role_for_import(_role), do: {:error, "Role must be 'operator' or 'viewer'"}

  defp validate_name_length(name) when byte_size(name) <= 255, do: :ok
  defp validate_name_length(_name), do: {:error, "Name must be 255 characters or less"}

  defp validate_contact_phone(phone) when byte_size(phone) <= 20, do: :ok
  defp validate_contact_phone(_phone), do: {:error, "Contact phone must be 20 characters or less"}

  ## User Creation from CSV Data

  defp create_users_from_csv_data(
         %{valid_rows: valid_rows} = validation_result,
         tenant_id,
         %User{} = current_user
       ) do
    Repo.transaction(fn ->
      created_users =
        valid_rows
        |> Enum.reduce([], fn row_data, acc ->
          case create_user_from_csv_row(row_data, current_user) do
            {:ok, user} -> [user | acc]
            # Skip failed creations but continue
            {:error, _changeset} -> acc
          end
        end)
        |> Enum.reverse()

      summary = %{
        total_rows: validation_result.total_rows,
        successful: length(created_users),
        failed:
          length(validation_result.invalid_rows) + (length(valid_rows) - length(created_users)),
        errors: validation_result.invalid_rows,
        created_users: created_users
      }

      # Log bulk import action
      log_action(current_user, "users.imported", %{
        resource_type: "BulkImport",
        changes: %{
          tenant_id: tenant_id,
          total_processed: summary.total_rows,
          successful: summary.successful,
          failed: summary.failed
        }
      })

      {:ok, summary}
    end)
  end

  defp create_user_from_csv_row(row_data, %User{} = creator) do
    # Use the existing create_user function with proper authorization
    attrs =
      Map.take(row_data, [
        :email,
        :role,
        :name,
        :contact_phone,
        :tenant_id,
        :status,
        :password,
        :password_reset_required
      ])

    scope = %RiceMill.Accounts.Scope{user: creator}

    # Handle unique constraint violations gracefully
    case create_user(attrs, scope) do
      {:ok, user} ->
        {:ok, user}
      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        # Check if it's a unique constraint error
        case Keyword.get(errors, :email) do
          {"has already been taken", _} -> {:error, :duplicate_email}
          _ -> {:error, changeset}
        end
      error ->
        error
    end
  end
end
