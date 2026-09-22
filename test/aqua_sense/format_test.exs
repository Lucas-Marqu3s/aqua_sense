defmodule AquaSense.FormatTest do
  use ExUnit.Case, async: true

  alias AquaSense.Format

  doctest AquaSense.Format

  describe "number/2" do
    test "usa vírgula decimal" do
      assert Format.number(75.83, 1) == "75,8"
      assert Format.number(3.0, 1) == "3,0"
    end

    test "zero casas não deixa vírgula sobrando" do
      assert Format.number(384, 0) == "384"
      assert Format.number(383.6, 0) == "384"
    end

    test "aceita inteiro e float igualmente" do
      assert Format.number(24, 1) == "24,0"
      assert Format.number(24.0, 1) == "24,0"
    end
  end

  describe "thousands/1" do
    test "separa milhares com ponto" do
      assert Format.thousands(15_160) == "15.160"
      assert Format.thousands(1_000_000) == "1.000.000"
    end

    test "número curto fica intacto" do
      assert Format.thousands(842) == "842"
      assert Format.thousands(0) == "0"
    end

    test "negativo mantém o sinal fora da separação" do
      assert Format.thousands(-2_340) == "-2.340"
    end
  end

  describe "signed/2" do
    test "positivo ganha sinal explícito, que é o ponto de um delta" do
      assert Format.signed(2.2, 1) == "+2,2"
    end

    test "negativo e zero não ganham" do
      assert Format.signed(-8.0, 0) == "-8"
      assert Format.signed(0.0, 1) == "0,0"
    end
  end
end
