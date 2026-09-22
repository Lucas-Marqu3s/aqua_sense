defmodule AquaSense.ChartTest do
  use ExUnit.Case, async: true

  alias AquaSense.Chart

  doctest AquaSense.Chart

  describe "build/2" do
    test "espalha os pontos pela largura e inverte o eixo vertical" do
      chart = Chart.build([0, 50, 100], x0: 0, x1: 100, y0: 0, y1: 10, min: 0, max: 100)

      assert chart.points == [{0.0, 10.0}, {50.0, 5.0}, {100.0, 0.0}]
    end

    test "o caminho da área fecha na base, para o preenchimento não vazar" do
      chart = Chart.build([10, 20], x0: 0, x1: 10, y0: 0, y1: 10, min: 0, max: 20)

      assert chart.area =~ "Z"
      assert String.starts_with?(chart.area, chart.line)
    end

    test "respeita min e max forçados em vez de ajustar aos dados" do
      chart = Chart.build([40, 60], x0: 0, x1: 10, y0: 0, y1: 100, min: 0, max: 100)

      # Com escala 0..100 nenhum ponto encosta nas bordas da caixa.
      assert chart.points == [{0.0, 60.0}, {10.0, 40.0}]
    end

    test "série sem variação fica no meio da caixa, não colada na base" do
      chart = Chart.build([7, 7, 7], x0: 0, x1: 10, y0: 0, y1: 10)

      assert chart.points == [{0.0, 5.0}, {5.0, 5.0}, {10.0, 5.0}]
    end

    test "uma leitura só não divide por zero" do
      chart = Chart.build([42], x0: 0, x1: 100, y0: 0, y1: 10)

      assert chart.points == [{0.0, 5.0}]
    end

    test "série vazia é erro de quem chamou, não gráfico em branco" do
      assert_raise ArgumentError, fn -> Chart.build([]) end
    end
  end

  describe "y/2" do
    test "converte um valor qualquer para a escala, mesmo fora da série" do
      chart = Chart.build([40, 60], x0: 0, x1: 10, y0: 0, y1: 100, min: 0, max: 100)

      assert Chart.y(chart, 0) == 100.0
      assert Chart.y(chart, 100) == 0.0
      # O limite legal não precisa estar entre as leituras para ser desenhado.
      assert Chart.y(chart, 90) == 10.0
    end
  end

  describe "x/2, point/2 e last_point/1" do
    setup do
      %{chart: Chart.build([1, 2, 3], x0: 0, x1: 10, y0: 0, y1: 10)}
    end

    test "último ponto é onde vai o rótulo direto", %{chart: chart} do
      assert Chart.last_point(chart) == %{x: 10.0, y: 0.0}
    end

    test "índice fora da série avisa em vez de desenhar torto", %{chart: chart} do
      assert_raise ArgumentError, fn -> Chart.x(chart, 99) end
      assert_raise ArgumentError, fn -> Chart.point(chart, 99) end
    end

    test "count/1 conta as leituras", %{chart: chart} do
      assert Chart.count(chart) == 3
    end
  end

  describe "nice_ticks/3" do
    test "usa números redondos em vez de dividir o intervalo em partes iguais" do
      assert Chart.nice_ticks(0, 100, 5) == [0.0, 25.0, 50.0, 75.0, 100.0]
      assert Chart.nice_ticks(250, 430, 5) == [250.0, 300.0, 350.0, 400.0]
      assert Chart.nice_ticks(23, 25.5, 4) == [23.0, 24.0, 25.0]
    end

    test "nunca passa do máximo" do
      for {min, max} <- [{0, 7}, {250, 430}, {23, 25.5}, {0, 100}] do
        ticks = Chart.nice_ticks(min, max, 5)

        assert Enum.all?(ticks, &(&1 >= min and &1 <= max)),
               "marcas #{inspect(ticks)} saíram de #{min}..#{max}"
      end
    end

    test "intervalo degenerado devolve uma marca só" do
      assert Chart.nice_ticks(5, 5, 4) == [5.0]
    end

    test "passo fracionário não acumula erro binário" do
      assert Chart.nice_ticks(0, 1, 5) == [0.0, 0.25, 0.5, 0.75, 1.0]
    end
  end
end
