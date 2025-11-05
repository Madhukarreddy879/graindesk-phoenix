defmodule RiceMill.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RiceMillWeb.Telemetry,
      RiceMill.Repo,
      {DNSCluster, query: Application.get_env(:rice_mill, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RiceMill.PubSub},
      # Start Cachex for dashboard caching
      {Cachex, name: :dashboard_cache, limit: 1000},
      # Start background jobs
      RiceMill.Accounts.Jobs.ExpireInvitations,
      # Start to serve requests, typically the last entry
      RiceMillWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RiceMill.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RiceMillWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
