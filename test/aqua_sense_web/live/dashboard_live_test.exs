defmodule AquaSenseWeb.DashboardLiveTest do
  @moduledoc """
  Testes de fumaça do painel.

  O painel exige sessão, então sem usuário a rota deve redirecionar. Os
  testes de conteúdo cobrem o que a tela promete: um veredito no topo, um
  cartão por parâmetro monitorado, e que turbidez (sem sensor no protótipo)
  e o banco vazio (antes da primeira publicação do ESP32) degradam sem
  fabricar dado nenhum.
  """
  use AquaSenseWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "sem sessão, redireciona para o login", %{conn: conn} do
    assert {:error, {:redirect, %{to: to}}} = live(conn, "/")
    assert to =~ "sign-in"
  end

  defp authenticate(conn) do
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

    conn
    |> Plug.Test.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end

  defp ingest_reading!(attrs) do
    AquaSense.Monitoring.Reading
    |> Ash.Changeset.for_create(:ingest, attrs)
    |> Ash.create!(domain: AquaSense.Monitoring, authorize?: false)
  end

  describe "sem nenhuma leitura ainda" do
    setup %{conn: conn}, do: %{conn: authenticate(conn)}

    test "o painel não quebra e mostra os cartões como sem dado", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      for key <- ~w(level temperature turbidity conductivity) do
        assert has_element?(view, "#param-#{key}")
      end

      assert view |> element("#param-level") |> render() =~ "Sem sensor"
    end
  end

  describe "com leituras registradas" do
    setup %{conn: conn} do
      ingest_reading!(%{
        device_id: "esp32-01",
        level: 73.6,
        temperature: 23.8,
        conductivity: 288.0
      })

      ingest_reading!(%{
        device_id: "esp32-01",
        level: 78.1,
        temperature: 24.0,
        conductivity: 290.0
      })

      %{conn: authenticate(conn)}
    end

    test "mostra um cartão por parâmetro monitorado", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      for key <- ~w(level temperature turbidity conductivity) do
        assert has_element?(view, "#param-#{key}")
      end
    end

    test "turbidez aparece marcada como sem sensor, sem dado fabricado", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert view |> element("#param-turbidity") |> render() =~ "Sem sensor"
    end

    test "abre na visão geral com o gráfico de nível", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

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

    test "atualiza sozinho quando chega uma leitura nova via PubSub", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      ingest_reading!(%{
        device_id: "esp32-01",
        level: 91.0,
        temperature: 26.5,
        conductivity: 410.0
      })

      assert render(view) =~ "91,0"
    end
  end
end
