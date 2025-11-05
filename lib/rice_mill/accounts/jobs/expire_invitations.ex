defmodule RiceMill.Accounts.Jobs.ExpireInvitations do
  @moduledoc """
  A GenServer that periodically expires old user invitations.

  This job runs daily at midnight to update the status of pending invitations
  that have passed their expiration date to :expired.
  """
  use GenServer
  require Logger
  alias RiceMill.Accounts

  # 24 hours in milliseconds
  @daily_interval 24 * 60 * 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually triggers the expiration job. Useful for testing or manual execution.
  """
  def run_now do
    GenServer.call(__MODULE__, :run_now)
  end

  @impl true
  def init(_opts) do
    # Schedule the first run
    schedule_next_run()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:run_now, _from, state) do
    result = expire_invitations()
    {:reply, result, state}
  end

  @impl true
  def handle_info(:expire_invitations, state) do
    expire_invitations()
    schedule_next_run()
    {:noreply, state}
  end

  defp expire_invitations do
    Logger.info("[ExpireInvitations] Starting invitation expiration job")

    result = Accounts.expire_old_invitations()

    case result do
      {count, _} when count > 0 ->
        Logger.info("[ExpireInvitations] Expired #{count} invitation(s)")

      {0, _} ->
        Logger.debug("[ExpireInvitations] No invitations to expire")

      error ->
        Logger.error("[ExpireInvitations] Error expiring invitations: #{inspect(error)}")
    end

    result
  end

  defp schedule_next_run do
    Process.send_after(self(), :expire_invitations, @daily_interval)
  end
end
