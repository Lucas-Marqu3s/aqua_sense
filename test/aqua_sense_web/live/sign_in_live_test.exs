defmodule AquaSenseWeb.SignInLiveTest do
  @moduledoc """
  Testes de fumaça da tela de entrada.

  Verificam a presença dos elementos por id, não o texto: a redação muda com
  frequência, os ganchos do formulário não.
  """
  use AquaSenseWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "login" do
    test "monta o formulário com e-mail, senha e envio", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign-in")

      assert has_element?(view, "#sign-in-form")
      assert has_element?(view, "#sign-in-email")
      assert has_element?(view, "#sign-in-password")
      assert has_element?(view, "#sign-in-submit")
    end

    test "o formulário envia para a rota de autenticação do Ash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign-in")

      assert has_element?(view, ~s(form[action="/auth/user/password/sign_in"]))
    end

    test "oferece caminho para solicitar cadastro e recuperar senha", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/sign-in")

      assert has_element?(view, ~s(a[href="/register"]))
      assert has_element?(view, ~s(a[href="/reset"]))
    end
  end

  describe "cadastro" do
    test "monta o formulário com confirmação de senha", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/register")

      assert has_element?(view, "#register-form")
      assert has_element?(view, "#register-name")
      assert has_element?(view, "#register-email")
      assert has_element?(view, "#register-password")
      assert has_element?(view, "#register-password-confirmation")
    end

    test "avisa que a conta passa por aprovação antes de existir", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/register")

      assert html =~ "liberado por um administrador"
    end
  end
end
