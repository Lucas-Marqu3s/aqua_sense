defmodule AquaSense.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AquaSenseWeb.Telemetry,
      AquaSense.Repo,
      {DNSCluster, query: Application.get_env(:aqua_sense, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AquaSense.PubSub},
      # Start a worker by calling: AquaSense.Worker.start_link(arg)
      # {AquaSense.Worker, arg},
      # Start to serve requests, typically the last entry
      AquaSenseWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AquaSense.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AquaSenseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
