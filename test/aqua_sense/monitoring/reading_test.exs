defmodule AquaSense.Monitoring.ReadingTest do
  use AquaSense.DataCase, async: true

  alias AquaSense.Monitoring.Reading

  defp ingest!(attrs) do
    Reading
    |> Ash.Changeset.for_create(:ingest, attrs)
    |> Ash.create!(domain: AquaSense.Monitoring, authorize?: false)
  end

  describe ":ingest" do
    test "grava uma leitura válida" do
      reading =
        ingest!(%{device_id: "esp32-01", level: 73.6, temperature: 23.8, conductivity: 288.0})

      assert reading.device_id == "esp32-01"
      assert reading.level == 73.6
      assert reading.temperature == 23.8
      assert reading.conductivity == 288.0
      assert reading.read_at
    end

    test "usa a data/hora do servidor quando read_at não é informado" do
      before = DateTime.utc_now()
      reading = ingest!(%{device_id: "esp32-01", level: 1.0, temperature: 1.0, conductivity: 1.0})

      assert DateTime.compare(reading.read_at, before) in [:gt, :eq]
    end

    test "falha quando falta um campo obrigatório" do
      result =
        Reading
        |> Ash.Changeset.for_create(:ingest, %{
          device_id: "esp32-01",
          level: 1.0,
          temperature: 1.0
        })
        |> Ash.create(domain: AquaSense.Monitoring, authorize?: false)

      assert {:error, _error} = result
    end
  end

  describe ":recent" do
    test "devolve as N leituras mais recentes, mais nova primeiro" do
      ingest!(%{device_id: "esp32-01", level: 1.0, temperature: 1.0, conductivity: 1.0})
      ingest!(%{device_id: "esp32-01", level: 2.0, temperature: 2.0, conductivity: 2.0})
      ingest!(%{device_id: "esp32-01", level: 3.0, temperature: 3.0, conductivity: 3.0})

      readings =
        Reading
        |> Ash.Query.for_read(:recent, %{limit: 2})
        |> Ash.read!(domain: AquaSense.Monitoring, authorize?: false)

      assert Enum.map(readings, & &1.level) == [3.0, 2.0]
    end
  end

  describe ":latest" do
    test "devolve só a leitura mais recente" do
      ingest!(%{device_id: "esp32-01", level: 1.0, temperature: 1.0, conductivity: 1.0})
      ingest!(%{device_id: "esp32-01", level: 2.0, temperature: 2.0, conductivity: 2.0})

      reading =
        Reading
        |> Ash.Query.for_read(:latest)
        |> Ash.read_one!(domain: AquaSense.Monitoring, authorize?: false)

      assert reading.level == 2.0
    end

    test "nenhuma leitura ainda: devolve nil" do
      reading =
        Reading
        |> Ash.Query.for_read(:latest)
        |> Ash.read_one!(domain: AquaSense.Monitoring, authorize?: false)

      assert reading == nil
    end
  end
end
