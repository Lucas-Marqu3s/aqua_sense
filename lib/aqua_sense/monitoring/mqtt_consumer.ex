defmodule AquaSense.Monitoring.MqttConsumer do
  @moduledoc """
  Assina `aquasense/+/leituras` no broker MQTT e persiste cada mensagem como
  uma `AquaSense.Monitoring.Reading`.

  Mensagem malformada (JSON inválido ou campo faltando) é logada e
  descartada — nunca derruba a conexão com o broker.
  """

  use Tortoise311.Handler

  require Logger

  alias AquaSense.Monitoring.Reading

  @impl true
  def init(_args), do: {:ok, %{}}

  @impl true
  def connection(:up, state) do
    Logger.info("MqttConsumer: conectado ao broker MQTT")
    {:ok, state}
  end

  def connection(:down, state) do
    Logger.warning("MqttConsumer: desconectado do broker MQTT")
    {:ok, state}
  end

  @impl true
  def handle_message(["aquasense", _device_id, "leituras"], payload, state) do
    case parse_payload(payload) do
      {:ok, params} ->
        Reading
        |> Ash.Changeset.for_create(:ingest, params)
        |> Ash.create(domain: AquaSense.Monitoring, authorize?: false)
        |> case do
          {:ok, _reading} ->
            :ok

          {:error, error} ->
            Logger.warning("MqttConsumer: falha ao gravar leitura: #{inspect(error)}")
        end

      {:error, reason} ->
        Logger.warning("MqttConsumer: payload descartado (#{reason}): #{inspect(payload)}")
    end

    {:ok, state}
  end

  def handle_message(topic, _payload, state) do
    Logger.warning("MqttConsumer: tópico inesperado #{inspect(topic)}")
    {:ok, state}
  end

  @doc """
  Decodifica e valida o payload publicado pelo dispositivo. Função pura,
  testável sem broker.
  """
  @spec parse_payload(binary) :: {:ok, map} | {:error, String.t()}
  def parse_payload(payload) do
    with {:ok, decoded} <- Jason.decode(payload),
         {:ok, device_id} <- fetch_string(decoded, "device_id"),
         {:ok, level} <- fetch_number(decoded, "nivel_pct"),
         {:ok, temperature} <- fetch_number(decoded, "temperatura_c"),
         {:ok, conductivity} <- fetch_number(decoded, "condutividade_us_cm") do
      {:ok,
       %{device_id: device_id, level: level, temperature: temperature, conductivity: conductivity}}
    else
      {:error, %Jason.DecodeError{}} -> {:error, "JSON inválido"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_string(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, "campo #{key} ausente ou inválido"}
    end
  end

  defp fetch_number(map, key) do
    case Map.get(map, key) do
      value when is_number(value) -> {:ok, value / 1}
      _other -> {:error, "campo #{key} ausente ou inválido"}
    end
  end
end
