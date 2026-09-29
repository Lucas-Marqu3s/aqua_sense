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
      {Tortoise311.Connection,
       client_id: AquaSense.MqttConsumer,
       server: {Tortoise311.Transport.Tcp, host: mqtt_config(:host), port: mqtt_config(:port)},
       user_name: mqtt_config(:username),
       password: mqtt_config(:password),
       handler: {AquaSense.Monitoring.MqttConsumer, []},
       subscriptions: [{"aquasense/+/leituras", 1}]},
      # Start to serve requests, typically the last entry
      AquaSenseWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :aqua_sense]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AquaSense.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp mqtt_config(key), do: Application.get_env(:aqua_sense, :mqtt)[key]

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AquaSenseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
