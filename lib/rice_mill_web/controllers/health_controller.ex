defmodule RiceMillWeb.HealthController do
  use RiceMillWeb, :controller

  @doc """
  Health check endpoint for load balancers and monitoring systems.
  Returns 200 OK if the application is running and can connect to the database.
  """
  def check(conn, _params) do
    case check_database() do
      :ok ->
        json(conn, %{status: "ok", timestamp: DateTime.utc_now()})

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", reason: reason, timestamp: DateTime.utc_now()})
    end
  end

  defp check_database do
    try do
      # Simple query to check database connectivity
      RiceMill.Repo.query!("SELECT 1")
      :ok
    rescue
      e ->
        {:error, "Database connection failed: #{Exception.message(e)}"}
    end
  end
end
