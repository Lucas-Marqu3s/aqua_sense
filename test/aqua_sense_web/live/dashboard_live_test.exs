defmodule AquaSenseWeb.DashboardLiveTest do
  @moduledoc """
  Testes de fumaça do painel.

  O painel exige sessão, então sem usuário a rota deve redirecionar. Os
  testes de conteúdo cobrem o que a tela promete: um veredito no topo e um
  cartão por parâmetro.
  """
  use AquaSenseWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "sem sessão, redireciona para o login", %{conn: conn} do
    assert {:error, {:redirect, %{to: to}}} = live(conn, "/")
    assert to =~ "sign-in"
  end

  describe "com usuário autenticado" do
    setup %{conn: conn} do
      user =
        AquaSense.Accounts.User
        |> Ash.Changeset.for_create(:register_with_password, %{
          name: "Maria Oliveira",
          email: "maria@facens.br",
          password: "senha-de-teste-123",
          password_confirmation: "senha-de-teste-123"
        })
        |> Ash.create!(domain: AquaSense.Accounts, authorize?: false)

      user =
        user
        |> Ash.Changeset.for_update(:confirm_user, %{})
        |> Ash.update!(domain: AquaSense.Accounts, authorize?: false)

      %{conn: AshAuthentication.Plug.Helpers.store_in_session(conn, user), user: user}
    end

    test "mostra um cartão por parâmetro monitorado", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      for key <- ~w(level temperature turbidity conductivity) do
        assert has_element?(view, "#param-#{key}")
      end
    end

    test "abre na visão geral com o veredito no topo", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Portaria"
      assert html =~ "Nível do reservatório"
    end

    test "trocar de aba troca o conteúdo", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element(~s(button[phx-value-tab="users"]))
        |> render_click()

      assert html =~ "Usuários cadastrados"
      assert has_element?(view, "#create-user-form")
    end

    test "o histórico troca o parâmetro em destaque", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element(~s(button[phx-value-tab="history"])) |> render_click()
      assert has_element?(view, "#grafico-historico")

      html =
        view
        |> element(~s(button[phx-click="set_chart_tab"][phx-value-tab="turbidity"]))
        |> render_click()

      assert html =~ "Turbidez"
    end
  end
end
