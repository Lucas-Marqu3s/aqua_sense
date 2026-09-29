defmodule AquaSense.Monitoring.MqttConsumerTest do
  use ExUnit.Case, async: true

  alias AquaSense.Monitoring.MqttConsumer

  describe "parse_payload/1" do
    test "decodifica um payload válido" do
      payload =
        Jason.encode!(%{
          device_id: "esp32-01",
          nivel_pct: 73.6,
          temperatura_c: 23.8,
          condutividade_us_cm: 288.0
        })

      assert {:ok, params} = MqttConsumer.parse_payload(payload)

      assert params == %{
               device_id: "esp32-01",
               level: 73.6,
               temperature: 23.8,
               conductivity: 288.0
             }
    end

    test "aceita números inteiros nos campos numéricos" do
      payload =
        Jason.encode!(%{
          device_id: "esp32-01",
          nivel_pct: 74,
          temperatura_c: 24,
          condutividade_us_cm: 290
        })

      assert {:ok, %{level: 74.0, temperature: 24.0, conductivity: 290.0}} =
               MqttConsumer.parse_payload(payload)
    end

    test "rejeita JSON inválido" do
      assert {:error, _reason} = MqttConsumer.parse_payload("não é json")
    end

    test "rejeita payload sem device_id" do
      payload = Jason.encode!(%{nivel_pct: 1.0, temperatura_c: 1.0, condutividade_us_cm: 1.0})

      assert {:error, _reason} = MqttConsumer.parse_payload(payload)
    end

    test "rejeita payload com campo numérico faltando" do
      payload = Jason.encode!(%{device_id: "esp32-01", nivel_pct: 1.0, temperatura_c: 1.0})

      assert {:error, _reason} = MqttConsumer.parse_payload(payload)
    end

    test "rejeita campo numérico com tipo errado" do
      payload =
        Jason.encode!(%{
          device_id: "esp32-01",
          nivel_pct: "alto",
          temperatura_c: 1.0,
          condutividade_us_cm: 1.0
        })

      assert {:error, _reason} = MqttConsumer.parse_payload(payload)
    end
  end
end
