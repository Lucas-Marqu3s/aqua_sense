defmodule AquaSense.Format do
  @moduledoc """
  Formatação numérica em português: vírgula decimal e ponto de milhar.

  O painel mostra leituras o tempo todo, então vale ter um lugar só para
  isso em vez de espalhar `String.replace(".", ",")` pelos templates.
  """

  @doc """
  Número com `decimals` casas, vírgula como separador decimal.

      iex> AquaSense.Format.number(75.83, 1)
      "75,8"

      iex> AquaSense.Format.number(384, 0)
      "384"
  """
  @spec number(number(), non_neg_integer()) :: String.t()
  def number(value, decimals \\ 1) do
    value
    |> :erlang.float()
    |> :erlang.float_to_binary(decimals: decimals)
    |> String.replace(".", ",")
  end

  @doc """
  Inteiro com ponto separando os milhares.

      iex> AquaSense.Format.thousands(15160)
      "15.160"
  """
  @spec thousands(integer()) :: String.t()
  def thousands(value) when is_integer(value) do
    value
    |> abs()
    |> Integer.to_string()
    |> String.reverse()
    |> String.codepoints()
    |> Enum.chunk_every(3)
    |> Enum.map_join(".", &Enum.join/1)
    |> String.reverse()
    |> then(fn text -> if value < 0, do: "-" <> text, else: text end)
  end

  @doc """
  Variação com sinal explícito, para deltas de 24 h.

      iex> AquaSense.Format.signed(2.2, 1)
      "+2,2"

      iex> AquaSense.Format.signed(-8.0, 0)
      "-8"
  """
  @spec signed(number(), non_neg_integer()) :: String.t()
  def signed(value, decimals \\ 1) do
    text = number(value, decimals)
    if value > 0, do: "+" <> text, else: text
  end
end
