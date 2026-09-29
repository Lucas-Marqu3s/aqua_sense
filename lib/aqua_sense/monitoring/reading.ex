defmodule AquaSense.Monitoring.Reading do
  @moduledoc """
  Uma leitura do reservatório (nível, temperatura, condutividade) publicada
  pelo ESP32 via MQTT e persistida pelo `AquaSense.Monitoring.MqttConsumer`.
  """

  use Ash.Resource,
    otp_app: :aqua_sense,
    domain: AquaSense.Monitoring,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "readings"
    repo AquaSense.Repo
  end

  actions do
    defaults [:read]

    create :ingest do
      description "Registra uma leitura publicada pelo dispositivo via MQTT."
      accept [:device_id, :level, :temperature, :conductivity, :read_at]
    end

    read :recent do
      description "As últimas N leituras, mais recente primeiro."
      argument :limit, :integer, default: 48, allow_nil?: false

      prepare fn query, _context ->
        limit = Ash.Query.get_argument(query, :limit)

        query
        |> Ash.Query.sort(read_at: :desc)
        |> Ash.Query.limit(limit)
      end
    end

    read :latest do
      description "A leitura mais recente."
      get? true

      prepare fn query, _context ->
        query
        |> Ash.Query.sort(read_at: :desc)
        |> Ash.Query.limit(1)
      end
    end
  end

  pub_sub do
    module AquaSenseWeb.Endpoint
    prefix "readings"

    publish :ingest, ["new"]
  end

  attributes do
    uuid_primary_key :id

    attribute :device_id, :string do
      allow_nil? false
      public? true
    end

    attribute :level, :float do
      allow_nil? false
      public? true
    end

    attribute :temperature, :float do
      allow_nil? false
      public? true
    end

    attribute :conductivity, :float do
      allow_nil? false
      public? true
    end

    attribute :read_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
    end
  end
end
