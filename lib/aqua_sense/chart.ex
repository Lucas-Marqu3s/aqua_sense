defmodule AquaSense.Chart do
  @moduledoc """
  Geometria dos gráficos: converte uma série de leituras em coordenadas SVG.

  Tudo aqui é função pura — nada depende de socket, assigns ou banco — para
  que a geometria possa ser testada sozinha. O template recebe os caminhos
  `d` já prontos e só os desenha.

  A caixa do gráfico é descrita pelos quatro limites em unidades do
  `viewBox`: `x0`/`x1` (esquerda/direita) e `y0`/`y1` (topo/base). O eixo Y
  do SVG cresce para baixo, então `y0 < y1` e o maior valor da série fica
  em `y0`.

      iex> chart = AquaSense.Chart.build([0, 50, 100], x0: 0, x1: 100, y0: 0, y1: 10, min: 0, max: 100)
      iex> chart.points
      [{0.0, 10.0}, {50.0, 5.0}, {100.0, 0.0}]
  """

  @enforce_keys [:points, :line, :area, :min, :max, :x0, :x1, :y0, :y1]
  defstruct [:points, :line, :area, :min, :max, :x0, :x1, :y0, :y1]

  @type t :: %__MODULE__{
          points: [{float(), float()}],
          line: String.t(),
          area: String.t(),
          min: float(),
          max: float(),
          x0: float(),
          x1: float(),
          y0: float(),
          y1: float()
        }

  @doc """
  Monta a geometria de uma série.

  Opções: `:x0`, `:x1`, `:y0`, `:y1` para a caixa, e `:min`/`:max` para fixar
  a escala vertical. Sem `:min`/`:max` a escala se ajusta aos dados — use os
  valores fixos quando o zero for significativo (porcentagem) ou quando
  várias leituras precisarem da mesma régua.
  """
  @spec build([number()], keyword()) :: t()
  def build(values, opts \\ [])

  def build([], _opts), do: raise(ArgumentError, "a série não pode ser vazia")

  def build(values, opts) when is_list(values) do
    x0 = num(opts[:x0], 0.0)
    x1 = num(opts[:x1], 100.0)
    y0 = num(opts[:y0], 0.0)
    y1 = num(opts[:y1], 100.0)

    min = num(opts[:min], Enum.min(values))
    max = num(opts[:max], Enum.max(values))

    last = length(values) - 1

    points =
      values
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        x = if last == 0, do: x0, else: x0 + index * (x1 - x0) / last
        {round1(x), scale(num(value, 0.0), min, max, y0, y1)}
      end)

    line = to_path(points)
    {first_x, _} = hd(points)
    {last_x, _} = List.last(points)

    %__MODULE__{
      points: points,
      line: line,
      area: line <> " L #{round1(last_x)} #{round1(y1)} L #{round1(first_x)} #{round1(y1)} Z",
      min: min,
      max: max,
      x0: x0,
      x1: x1,
      y0: y0,
      y1: y1
    }
  end

  @doc "Coordenada Y de um valor da série, na escala do gráfico."
  @spec y(t(), number()) :: float()
  def y(%__MODULE__{} = chart, value) do
    scale(num(value, 0.0), chart.min, chart.max, chart.y0, chart.y1)
  end

  # Série sem variação nenhuma não tem escala: desenha no meio da caixa, que
  # é mais honesto do que colar a linha reta na base ou no topo.
  defp scale(_value, min, max, y0, y1) when max - min == 0.0, do: round1((y0 + y1) / 2)

  defp scale(value, min, max, y0, y1) do
    round1(y1 - (value - min) / (max - min) * (y1 - y0))
  end

  @doc "Coordenada X do enésimo ponto (base zero)."
  @spec x(t(), non_neg_integer()) :: float()
  def x(%__MODULE__{points: points}, index) do
    case Enum.at(points, index) do
      {x, _y} -> x
      nil -> raise ArgumentError, "índice #{index} fora da série"
    end
  end

  @doc """
  Enésimo ponto como mapa, para marcadores no template.

      iex> chart = AquaSense.Chart.build([0, 100], x0: 0, x1: 10, y0: 0, y1: 10)
      iex> AquaSense.Chart.point(chart, 1)
      %{x: 10.0, y: 0.0}
  """
  @spec point(t(), non_neg_integer()) :: %{x: float(), y: float()}
  def point(%__MODULE__{points: points}, index) do
    case Enum.at(points, index) do
      {x, y} -> %{x: x, y: y}
      nil -> raise ArgumentError, "índice #{index} fora da série"
    end
  end

  @doc "Último ponto da série — o valor de agora, onde vai o rótulo direto."
  @spec last_point(t()) :: %{x: float(), y: float()}
  def last_point(%__MODULE__{points: points}) do
    {x, y} = List.last(points)
    %{x: x, y: y}
  end

  @doc "Quantidade de leituras da série."
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{points: points}), do: length(points)

  @doc """
  Marcas do eixo em números redondos dentro de `min..max`.

  Devolve no máximo `count` marcas, arredondando o passo para 1, 2, 2,5, 5 ou
  10 vezes uma potência de dez — é o que evita eixos com rótulos como 23,33.

      iex> AquaSense.Chart.nice_ticks(0, 100, 5)
      [0.0, 25.0, 50.0, 75.0, 100.0]

      iex> AquaSense.Chart.nice_ticks(250, 430, 5)
      [250.0, 300.0, 350.0, 400.0]
  """
  @spec nice_ticks(number(), number(), pos_integer()) :: [float()]
  def nice_ticks(min, max, count \\ 5) when count > 1 do
    min = num(min, 0.0)
    max = num(max, 0.0)
    span = max - min

    if span <= 0.0 do
      [min]
    else
      raw = span / (count - 1)
      magnitude = :math.pow(10.0, Float.floor(:math.log10(raw)))
      step = step_for(raw / magnitude) * magnitude
      first = Float.ceil(min / step) * step
      tolerance = step * 1.0e-9

      first
      |> Stream.iterate(&(&1 + step))
      |> Enum.take_while(&(&1 <= max + tolerance))
      |> Enum.map(&round_tick(&1, step))
    end
  end

  defp step_for(ratio) when ratio <= 1.0, do: 1.0
  defp step_for(ratio) when ratio <= 2.0, do: 2.0
  defp step_for(ratio) when ratio <= 2.5, do: 2.5
  defp step_for(ratio) when ratio <= 5.0, do: 5.0
  defp step_for(_ratio), do: 10.0

  # Passos fracionários somados repetidamente acumulam erro binário; corta na
  # casa decimal do próprio passo.
  defp round_tick(value, step) when step >= 1.0, do: Float.round(value, 2)
  defp round_tick(value, _step), do: Float.round(value, 4)

  defp to_path(points) do
    "M " <> Enum.map_join(points, " L ", fn {x, y} -> "#{x} #{y}" end)
  end

  defp num(nil, fallback), do: num(fallback, 0.0)
  defp num(value, _fallback) when is_float(value), do: value
  defp num(value, _fallback) when is_integer(value), do: value * 1.0

  defp round1(value), do: Float.round(value * 1.0, 1)
end
