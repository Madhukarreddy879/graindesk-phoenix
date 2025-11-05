defmodule RiceMillWeb.UserAuth do
  use RiceMillWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias RiceMill.Accounts
  alias RiceMill.Accounts.Scope

  # Make the remember me cookie valid for 14 days. This should match
  # the session validity setting in UserToken.
  @max_cookie_age_in_days 14
  @remember_me_cookie "_rice_mill_web_user_remember_me"
  @remember_me_options [
    sign: true,
    max_age: @max_cookie_age_in_days * 24 * 60 * 60,
    same_site: "Lax"
  ]

  # How old the session token should be before a new one is issued. When a request is made
  # with a session token older than this value, then a new session token will be created
  # and the session and remember-me cookies (if set) will be updated with the new token.
  # Lowering this value will result in more tokens being created by active users. Increasing
  # it will result in less time before a session token expires for a user to get issued a new
  # token. This can be set to a value greater than `@max_cookie_age_in_days` to disable
  # the reissuing of tokens completely.
  @session_reissue_age_in_days 7

  @doc """
  Logs the user in.

  Redirects to the session's `:user_return_to` path
  or falls back to the `signed_in_path/1`.
  """
  def log_in_user(conn, user, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)

    # Update last login time
    Accounts.update_last_login(user)

    # Log successful login audit entry
    Accounts.log_action(user, "login.success", %{
      resource_type: "Session",
      resource_id: user.id,
      ip_address: format_ip_address(conn.remote_ip),
      user_agent: get_user_agent(conn)
    })

    conn
    |> delete_session(:user_return_to)
    |> create_or_extend_session(user, params)
    |> redirect(to: user_return_to || signed_in_path_for_user(user))
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)

    # Log logout audit entry before clearing session
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      user = conn.assigns.current_scope.user

      Accounts.log_action(user, "logout", %{
        resource_type: "Session",
        resource_id: user.id,
        ip_address: format_ip_address(conn.remote_ip),
        user_agent: get_user_agent(conn)
      })
    end

    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      RiceMillWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session(nil)
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session and remember me token.

  Will reissue the session token if it is older than the configured age.
  Expires sessions after 24 hours of inactivity.
  """
  def fetch_current_scope_for_user(conn, _opts) do
    with {token, conn} <- ensure_user_token(conn),
         {user, token_inserted_at} <- Accounts.get_user_by_session_token(token) do
      # Check if user is active
      if user.status == :active do
        # Update session activity timestamp
        Accounts.update_session_activity(token)

        # Check if user needs to reset their password
        conn =
          if user.password_reset_required do
            conn
            |> put_session(:password_reset_required, true)
          else
            conn
            |> delete_session(:password_reset_required)
          end

        conn
        |> assign(:current_scope, Scope.for_user(user))
        |> maybe_reissue_user_session_token(user, token_inserted_at)
      else
        # User is inactive, clear session and treat as not logged in
        conn
        |> configure_session(renew: true)
        |> clear_session()
        |> delete_resp_cookie(@remember_me_cookie)
        |> assign(:current_scope, Scope.for_user(nil))
      end
    else
      nil ->
        # Session expired or invalid
        conn
        |> assign(:current_scope, Scope.for_user(nil))
    end
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, conn |> put_token_in_session(token) |> put_session(:user_remember_me, true)}
      else
        nil
      end
    end
  end

  # Reissue the session token if it is older than the configured reissue age.
  defp maybe_reissue_user_session_token(conn, user, token_inserted_at) do
    token_age = DateTime.diff(DateTime.utc_now(:second), token_inserted_at, :day)

    if token_age >= @session_reissue_age_in_days do
      create_or_extend_session(conn, user, %{})
    else
      conn
    end
  end

  # This function is the one responsible for creating session tokens
  # and storing them safely in the session and cookies. It may be called
  # either when logging in, during sudo mode, or to renew a session which
  # will soon expire.
  #
  # When the session is created, rather than extended, the renew_session
  # function will clear the session to avoid fixation attacks. See the
  # renew_session function to customize this behaviour.
  defp create_or_extend_session(conn, user, params) do
    token = Accounts.generate_user_session_token(user)
    remember_me = get_session(conn, :user_remember_me)

    conn
    |> renew_session(user)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
  end

  # Do not renew session if the user is already logged in
  # to prevent CSRF errors or data being lost in tabs that are still open
  defp renew_session(conn, user) do
    case conn.assigns[:current_scope] do
      %{user: %{id: user_id}} when user_id == user.id ->
        conn

      _ ->
        do_renew_session(conn)
    end
  end

  defp do_renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end



  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:user_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, user_session_topic(token))
  end

  @doc """
  Disconnects existing sockets for the given tokens.
  This function is kept for backward compatibility but now also listens to PubSub events.
  """
  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      RiceMillWeb.Endpoint.broadcast(user_session_topic(token), "disconnect", %{})
    end)
  end

  defp user_session_topic(token), do: "users_sessions:#{Base.url_encode64(token)}"

  @doc """
  Subscribes to session disconnect events from PubSub.
  This is called automatically when a LiveView socket connects.
  """
  def subscribe_to_session_events(token) do
    Phoenix.PubSub.subscribe(RiceMill.PubSub, user_session_topic(token))
  end

  @doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_scope` - Assigns current_scope
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:require_authenticated` - Authenticates the user from the session,
      and assigns the current_scope to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the `current_scope`:

      defmodule RiceMillWeb.PageLive do
        use RiceMillWeb, :live_view

        on_mount {RiceMillWeb.UserAuth, :mount_current_scope}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{RiceMillWeb.UserAuth, :require_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.user do
      # Check if user needs to reset their password
      if session["password_reset_required"] do
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "You must change your password before continuing.")
          |> Phoenix.LiveView.redirect(to: ~p"/users/settings")

        {:halt, socket}
      else
        {:cont, socket}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:require_sudo_mode, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if Accounts.sudo_mode?(socket.assigns.current_scope.user, -10) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must re-authenticate to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:require_tenant_user, _params, _session, socket) do
    user = socket.assigns.current_scope.user

    # Check if user has a tenant (not a super admin)
    if user.tenant_id do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "This page is only accessible to tenant users.")
        |> Phoenix.LiveView.redirect(to: ~p"/admin/tenants")

      {:halt, socket}
    end
  end

  def on_mount(:set_current_path, _params, _session, socket) do
    socket =
      Phoenix.LiveView.attach_hook(socket, :set_current_path, :handle_params, fn
        _params, url, socket ->
          {:cont, Phoenix.Component.assign(socket, :current_path, URI.parse(url).path)}
      end)

    {:cont, socket}
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      {user, _} =
        if user_token = session["user_token"] do
          Accounts.get_user_by_session_token(user_token)
        end || {nil, nil}

      Scope.for_user(user)
    end)
  end

  @doc "Returns the path to redirect to after log in."
  def signed_in_path(%Plug.Conn{
        assigns: %{current_scope: %Scope{user: %Accounts.User{role: role}}}
      }) do
    case role do
      :super_admin -> ~p"/admin/dashboard"
      :company_admin -> ~p"/dashboard"
      :operator -> ~p"/dashboard"
      :viewer -> ~p"/dashboard"
      _ -> ~p"/"
    end
  end

  def signed_in_path(_), do: ~p"/"

  @doc "Returns the path to redirect to after log in for a specific user."
  def signed_in_path_for_user(%Accounts.User{role: role}) do
    case role do
      :super_admin -> ~p"/admin/dashboard"
      :company_admin -> ~p"/dashboard"
      :operator -> ~p"/dashboard"
      :viewer -> ~p"/dashboard"
      _ -> ~p"/"
    end
  end

  def signed_in_path_for_user(_), do: ~p"/"

  @doc """
  Plug for routes that require the user to be authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      # Check if user needs to reset their password
      if get_session(conn, :password_reset_required) do
        conn
        |> put_flash(:info, "You must change your password before continuing.")
        |> redirect(to: ~p"/users/settings")
        |> halt()
      else
        conn
      end
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  @doc """
  Plug for routes that should redirect if the user is already authenticated.
  Used for login, registration, and similar pages.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user do
      conn
      |> redirect(to: signed_in_path_for_user(conn.assigns.current_scope.user))
      |> halt()
    else
      conn
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp format_ip_address(ip_tuple) when is_tuple(ip_tuple) do
    ip_tuple
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      _ -> nil
    end
  end
end
