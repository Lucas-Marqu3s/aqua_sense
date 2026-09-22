defmodule AquaSenseWeb.DashboardLive do
  @moduledoc """
  Painel de monitoramento do reservatório.

  As leituras ainda são fixas — o caminho ESP32 → MQTT → banco não está
  ligado. Ficam todas em `@readings`, já no formato que a consulta real vai
  devolver (lista de valores em ordem cronológica, mais antigo primeiro),
  para que trocar a origem seja mexer só em `readings/1`.

  O que o painel mostra é derivado desses valores, não escrito à mão: a
  variação em 24 h, a posição na barra de limite e a situação de cada
  parâmetro saem de `parameter_view/1`. Mudar uma leitura muda a etiqueta de
  situação junto, que é o mínimo para um painel em que a cor significa algo.
  """
  use AquaSenseWeb, :live_view

  alias AquaSense.Chart
  alias AquaSense.Format

  on_mount {AquaSenseWeb.LiveUserAuth, :live_user_required}

  # 48 leituras = 24 h a cada 30 min.
  @level [
    74.2,
    73.6,
    73.0,
    72.4,
    71.8,
    71.1,
    70.5,
    69.8,
    69.1,
    68.4,
    67.6,
    66.9,
    66.1,
    65.4,
    64.6,
    63.9,
    63.1,
    62.4,
    61.8,
    61.2,
    60.7,
    60.3,
    59.9,
    59.6,
    62.8,
    68.4,
    74.9,
    80.2,
    84.1,
    86.3,
    87.1,
    86.8,
    86.3,
    85.7,
    85.0,
    84.3,
    83.5,
    82.8,
    82.0,
    81.3,
    80.5,
    79.8,
    79.0,
    78.3,
    77.6,
    76.9,
    76.3,
    75.8
  ]

  @temperature [
    23.9,
    23.8,
    23.8,
    23.7,
    23.7,
    23.6,
    23.6,
    23.5,
    23.5,
    23.4,
    23.4,
    23.4,
    23.3,
    23.3,
    23.3,
    23.4,
    23.5,
    23.6,
    23.8,
    23.9,
    24.1,
    24.2,
    24.3,
    24.4,
    24.2,
    23.9,
    23.6,
    23.4,
    23.3,
    23.3,
    23.4,
    23.5,
    23.7,
    23.9,
    24.1,
    24.3,
    24.5,
    24.7,
    24.8,
    24.9,
    24.9,
    24.8,
    24.7,
    24.6,
    24.5,
    24.4,
    24.3,
    24.3
  ]

  @turbidity [
    1.9,
    1.9,
    2.0,
    2.0,
    2.1,
    2.1,
    2.2,
    2.2,
    2.3,
    2.3,
    2.4,
    2.4,
    2.5,
    2.5,
    2.6,
    2.6,
    2.7,
    2.7,
    2.8,
    2.8,
    2.9,
    2.9,
    3.0,
    3.0,
    4.9,
    6.2,
    5.4,
    4.6,
    4.0,
    3.6,
    3.3,
    3.1,
    3.0,
    2.9,
    2.9,
    2.8,
    2.8,
    2.8,
    2.9,
    2.9,
    3.0,
    3.0,
    3.1,
    3.1,
    3.2,
    3.2,
    3.2,
    3.2
  ]

  @conductivity [
    286,
    288,
    290,
    292,
    295,
    297,
    299,
    302,
    304,
    306,
    309,
    311,
    313,
    316,
    318,
    320,
    323,
    325,
    327,
    330,
    332,
    334,
    337,
    339,
    330,
    318,
    309,
    304,
    302,
    303,
    306,
    310,
    315,
    320,
    326,
    331,
    337,
    342,
    348,
    353,
    358,
    362,
    367,
    371,
    375,
    378,
    381,
    384
  ]

  @readings %{
    level: @level,
    temperature: @temperature,
    turbidity: @turbidity,
    conductivity: @conductivity
  }

  # Definição de cada parâmetro monitorado. `limit` é o teto legal da Portaria
  # GM/MS nº 888/2021; `floor` é um piso operacional (só o nível tem).
  # `bar_max` é o fim da régua da barrinha do cartão, não o limite.
  @parameters [
    %{
      key: :level,
      series: :level,
      label: "Nível",
      unit: "%",
      delta_unit: "pp",
      icon: "hero-beaker",
      decimals: 1,
      limit: nil,
      floor: 20.0,
      limit_label: "mín. 20%",
      bar_max: 100.0,
      scale: {0.0, 100.0},
      spark_scale: {55.0, 92.0}
    },
    %{
      key: :temperature,
      series: :temp,
      label: "Temperatura",
      unit: "°C",
      delta_unit: "°C",
      icon: "hero-fire",
      decimals: 1,
      limit: 30.0,
      floor: nil,
      limit_label: "máx. 30 °C",
      bar_max: 35.0,
      scale: {23.0, 25.5},
      spark_scale: {23.0, 25.6}
    },
    %{
      key: :turbidity,
      series: :turb,
      label: "Turbidez",
      unit: "NTU",
      delta_unit: "NTU",
      icon: "hero-eye-dropper",
      decimals: 1,
      limit: 5.0,
      floor: nil,
      limit_label: "máx. 5 NTU",
      bar_max: 8.0,
      scale: {0.0, 7.0},
      spark_scale: {0.0, 8.0}
    },
    %{
      key: :conductivity,
      series: :cond,
      label: "Condutividade",
      unit: "μS/cm",
      delta_unit: "μS/cm",
      icon: "hero-bolt",
      decimals: 0,
      limit: 400.0,
      floor: nil,
      limit_label: "máx. 400 μS/cm",
      bar_max: 500.0,
      scale: {250.0, 430.0},
      spark_scale: {260.0, 440.0}
    }
  ]

  @alerts [
    %{
      id: 1,
      tone: :warn,
      title: "Condutividade acima do esperado",
      detail:
        "A média móvel de 6 h ultrapassou 360 μS/cm e a curva segue subindo. Pode indicar infiltração salina ou saturação do filtro.",
      meta: "Hoje, 14:30 · condutividade · 384 μS/cm",
      badge: "Atenção",
      open?: true
    },
    %{
      id: 2,
      tone: :crit,
      title: "Sonda de turbidez sem resposta",
      detail:
        "Três leituras perdidas entre 09:02 e 09:34. A série foi reconstituída por interpolação e está marcada como estimada no histórico.",
      meta: "Hoje, 09:34 · turbidez · sem dado",
      badge: "Crítico",
      open?: true
    },
    %{
      id: 3,
      tone: :info,
      title: "Recarga do poço detectada",
      detail:
        "Subida de 27,5 pontos percentuais em 3 h, compatível com recarga natural após precipitação.",
      meta: "Hoje, 09:00 · nível · 59,6 → 87,1 %",
      badge: "Informativo",
      open?: false
    },
    %{
      id: 4,
      tone: :ok,
      title: "Relatório diário conferido",
      detail:
        "Todos os parâmetros de ontem permaneceram dentro dos limites da Portaria GM/MS nº 888/2021 nas 48 leituras do dia.",
      meta: "Hoje, 08:00 · sistema",
      badge: "Resolvido",
      open?: false
    }
  ]

  @system_status [
    %{name: "Sonda ESP32", detail: "firmware v2.1.3 · 14:30", tone: :ok, label: "Online"},
    %{name: "Broker MQTT", detail: "mosquitto 2.0.18", tone: :ok, label: "Online"},
    %{name: "PostgreSQL", detail: "v15.4 · 2,3 GB", tone: :ok, label: "Online"},
    %{name: "Backend Phoenix", detail: "1.8 · Ash 3.0", tone: :ok, label: "Online"},
    %{name: "Rede WiFi", detail: "RSSI −72 dBm", tone: :warn, label: "Instável"}
  ]

  @legal_limits [
    %{parameter: "Turbidez", limit: "≤ 5 NTU"},
    %{parameter: "Temperatura", limit: "≤ 30 °C"},
    %{parameter: "Condutividade", limit: "≤ 400 μS/cm"},
    %{parameter: "pH", limit: "6,0 – 9,5"},
    %{parameter: "Cloro residual livre", limit: "0,2 – 5,0 mg/L"}
  ]

  # Marcas do eixo do tempo: apontam para posições da própria série, então
  # continuam certas se a janela mudar de tamanho.
  @x_labels [
    %{index: 0, text: "00h", anchor: "start"},
    %{index: 8, text: "04h", anchor: "middle"},
    %{index: 16, text: "08h", anchor: "middle"},
    %{index: 24, text: "12h", anchor: "middle"},
    %{index: 32, text: "16h", anchor: "middle"},
    %{index: 40, text: "20h", anchor: "middle"},
    %{index: 47, text: "agora", anchor: "end"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    users = list_users()
    parameters = Enum.map(@parameters, &parameter_view/1)
    open_alerts = Enum.count(@alerts, & &1.open?)

    {:ok,
     socket
     |> assign(
       page_title: "Visão geral",
       active_tab: "overview",
       chart_tab: "conductivity",
       parameters: parameters,
       banner: banner(parameters),
       level: List.last(@level),
       alerts: @alerts,
       open_alerts: open_alerts,
       system_status: @system_status,
       legal_limits: @legal_limits,
       x_labels: @x_labels,
       nav: nav_groups(open_alerts),
       device: %{
         online?: true,
         label: "Sonda transmitindo",
         detail: "Última leitura 14:30 · RSSI −72 dBm"
       },
       users: users,
       user_form: %{name: "", email: "", error: nil, success: nil}
     )
     |> assign_charts()}
  end

  @impl true
  def handle_event("set_nav", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab, page_title: tab_title(tab))}
  end

  def handle_event("set_chart_tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(chart_tab: tab) |> assign_charts()}
  end

  def handle_event(
        "create_user",
        %{"name" => name, "email" => email, "password" => password},
        socket
      ) do
    result =
      AquaSense.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        name: name,
        email: email,
        password: password,
        password_confirmation: password
      })
      |> Ash.create(domain: AquaSense.Accounts, authorize?: false)

    case result do
      {:ok, user} ->
        # Quem o administrador cria já entra liberado.
        user
        |> Ash.Changeset.for_update(:confirm_user, %{})
        |> Ash.update(domain: AquaSense.Accounts, authorize?: false)

        {:noreply,
         assign(socket,
           users: list_users(),
           user_form: %{name: "", email: "", error: nil, success: "Usuário criado com sucesso."}
         )}

      {:error, error} ->
        form = %{socket.assigns.user_form | error: user_error_message(error), success: nil}
        {:noreply, assign(socket, user_form: form)}
    end
  end

  def handle_event("confirm_user", %{"id" => id}, socket) do
    AquaSense.Accounts.User
    |> Ash.get!(id, domain: AquaSense.Accounts, authorize?: false)
    |> Ash.Changeset.for_update(:confirm_user, %{})
    |> Ash.update(domain: AquaSense.Accounts, authorize?: false)
    |> case do
      {:ok, _user} -> {:noreply, assign(socket, users: list_users())}
      {:error, _error} -> {:noreply, socket}
    end
  end

  @doc """
  Parâmetro em destaque no histórico, conforme a aba escolhida.
  """
  def selected_parameter(parameters, chart_tab) do
    Enum.find(parameters, hd(parameters), &(Atom.to_string(&1.key) == chart_tab))
  end

  # ── montagem dos gráficos ─────────────────────────────────────────────────

  defp assign_charts(socket) do
    selected = selected_parameter(socket.assigns.parameters, socket.assigns.chart_tab)
    {min, max} = selected.scale

    assign(socket,
      # Nível é a série do topo: porcentagem tem zero significativo, então o
      # eixo começa em zero e o preenchimento sob a curva é honesto.
      level_chart: Chart.build(@level, x0: 44, x1: 740, y0: 16, y1: 250, min: 0, max: 100),
      level_ticks: Chart.nice_ticks(0, 100, 5),
      history: selected,
      history_chart:
        Chart.build(readings(selected.key), x0: 56, x1: 1090, y0: 22, y1: 300, min: min, max: max),
      history_ticks: Chart.nice_ticks(min, max, 5)
    )
  end

  defp parameter_view(parameter) do
    values = readings(parameter.key)
    value = List.last(values)
    first = hd(values)
    {spark_min, spark_max} = parameter.spark_scale
    {scale_min, scale_max} = parameter.scale
    tone = tone_for(value, parameter)

    parameter
    |> Map.merge(%{
      value: value,
      formatted: Format.number(value, parameter.decimals),
      delta: "#{Format.signed(value - first, parameter.decimals)} #{parameter.delta_unit}",
      delta_dir: if(value >= first, do: :up, else: :down),
      tone: tone,
      tone_label: tone_label(tone),
      fill_pct: value / parameter.bar_max * 100,
      limit_pct: (parameter.limit || parameter.floor) / parameter.bar_max * 100,
      spark: Chart.build(values, x0: 0, x1: 240, y0: 6, y1: 38, min: spark_min, max: spark_max),
      small: Chart.build(values, x0: 40, x1: 296, y0: 10, y1: 92, min: scale_min, max: scale_max),
      small_ticks: Chart.nice_ticks(scale_min, scale_max, 4),
      dom_id: "param-#{parameter.key}"
    })
  end

  # ── regras de situação ────────────────────────────────────────────────────

  # Parâmetro com piso (o nível): crítico abaixo do mínimo, atenção na
  # margem logo acima dele.
  defp tone_for(value, %{limit: nil, floor: floor}) when is_number(floor) do
    cond do
      value < floor -> :crit
      value < floor * 1.5 -> :warn
      true -> :ok
    end
  end

  # Parâmetro com teto legal: crítico acima dele, atenção a partir de 90% —
  # é o aviso antecipado, para dar tempo de agir antes de estourar.
  defp tone_for(value, %{limit: limit}) when is_number(limit) do
    cond do
      value > limit -> :crit
      value >= limit * 0.9 -> :warn
      true -> :ok
    end
  end

  # Veredito do topo do painel: o pior parâmetro manda. Responder "está tudo
  # bem?" é a primeira função da tela, antes de qualquer número.
  defp banner(parameters) do
    case Enum.sort_by(parameters, &tone_rank(&1.tone)) do
      [%{tone: :ok} | _rest] ->
        %{
          tone: :ok,
          title: "Todos os parâmetros dentro do padrão",
          detail:
            "As quatro leituras das últimas 24 h ficaram abaixo dos limites da Portaria GM/MS nº 888/2021."
        }

      [worst | _rest] ->
        %{
          tone: worst.tone,
          title: banner_title(worst.tone),
          detail: banner_detail(worst)
        }
    end
  end

  defp tone_rank(:crit), do: 0
  defp tone_rank(:warn), do: 1
  defp tone_rank(:ok), do: 2

  defp banner_title(:crit), do: "1 parâmetro fora do limite legal"
  defp banner_title(:warn), do: "1 parâmetro se aproximando do limite"

  defp banner_detail(%{limit: limit} = parameter) when is_number(limit) do
    pct = round(parameter.value / limit * 100)

    "#{parameter.label} em #{parameter.formatted} #{parameter.unit} — #{pct}% do teto de " <>
      "#{Format.number(limit, 0)} #{parameter.unit} da Portaria GM/MS nº 888/2021."
  end

  defp banner_detail(%{floor: floor} = parameter) do
    "#{parameter.label} em #{parameter.formatted} #{parameter.unit}, contra o mínimo " <>
      "operacional de #{Format.number(floor, 0)} #{parameter.unit}."
  end

  defp tone_label(:ok), do: "Normal"
  defp tone_label(:warn), do: "Atenção"
  defp tone_label(:crit), do: "Crítico"

  # ── auxiliares ────────────────────────────────────────────────────────────

  defp readings(key), do: Map.fetch!(@readings, key)

  defp list_users do
    AquaSense.Accounts.User |> Ash.read!(domain: AquaSense.Accounts, authorize?: false)
  end

  defp nav_groups(open_alerts) do
    [
      %{
        label: "Monitoramento",
        items: [
          %{id: "overview", label: "Visão geral", icon: "hero-squares-2x2", badge: nil},
          %{id: "history", label: "Histórico", icon: "hero-chart-bar", badge: nil},
          %{
            id: "alerts",
            label: "Alertas",
            icon: "hero-bell",
            badge: if(open_alerts > 0, do: Integer.to_string(open_alerts))
          }
        ]
      },
      %{
        label: "Administração",
        items: [
          %{id: "users", label: "Usuários", icon: "hero-users", badge: nil},
          %{id: "settings", label: "Sistema", icon: "hero-server-stack", badge: nil}
        ]
      }
    ]
  end

  defp tab_title("overview"), do: "Visão geral"
  defp tab_title("history"), do: "Histórico de medições"
  defp tab_title("alerts"), do: "Alertas"
  defp tab_title("users"), do: "Usuários e acesso"
  defp tab_title("settings"), do: "Sistema"
  defp tab_title(_other), do: "Visão geral"

  defp user_error_message(%{errors: [first | _]}) do
    case first do
      %{message: message} when is_binary(message) -> message
      %{messages: [message | _]} -> message
      _other -> "Não foi possível criar o usuário."
    end
  end

  defp user_error_message(_error), do: "Não foi possível criar o usuário."
end
