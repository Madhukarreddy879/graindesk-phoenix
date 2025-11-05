defmodule RiceMillWeb.Plugs.RequireRole do
  @moduledoc """
  Plug for route authorization based on user roles.

  This plug checks if the current user has one of the required roles
  to access a route. If unauthorized, it redirects to the home page
  with an error message and logs the authorization failure.

  ## Usage

  Add to a pipeline or route:

      pipe_through [:browser, :require_authenticated_user, {RiceMillWeb.Plugs.RequireRole, [:super_admin]}]

  Or in a scope:

      scope "/admin", RiceMillWeb do
        pipe_through [:browser, :require_authenticated_user, {RiceMillWeb.Plugs.RequireRole, [:super_admin, :company_admin]}]
        # routes here
      end
  """

  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Initializes the plug with the allowed roles.
  """
  def init(roles) when is_list(roles) do
    roles
  end

  def init(role) when is_atom(role) do
    [role]
  end

  @doc """
  Checks if the current user has one of the required roles.
  """
  def call(conn, allowed_roles) do
    case conn.assigns[:current_scope] do
      %{user: user} when not is_nil(user) ->
        if user.role in allowed_roles do
          conn
        else
          handle_unauthorized(conn, user, allowed_roles)
        end

      _ ->
        # No authenticated user, let the authentication plug handle this
        conn
    end
  end

  defp handle_unauthorized(conn, user, allowed_roles) do
    alias RiceMill.Accounts

    # Log authorization failure
    Accounts.log_action(user, "authorization.failed", %{
      resource_type: "Route",
      changes: %{
        path: conn.request_path,
        user_role: user.role,
        required_roles: allowed_roles
      },
      ip_address: format_ip_address(conn.remote_ip),
      user_agent: get_user_agent(conn)
    })

    conn
    |> put_flash(:error, "You don't have permission to access this page.")
    |> redirect(to: "/")
    |> halt()
  end

  defp format_ip_address(ip_tuple) when is_tuple(ip_tuple) do
    ip_tuple
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp format_ip_address(_), do: nil

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      _ -> nil
    end
  end
end
