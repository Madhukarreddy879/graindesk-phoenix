defmodule RiceMillWeb.Plugs.SetCurrentPath do
  @moduledoc """
  Plug to set the current request path in the connection assigns.
  This is used for highlighting active navigation links.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :current_path, conn.request_path)
  end
end
