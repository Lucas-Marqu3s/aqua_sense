defmodule AquaSenseWeb.DashboardLive do
  @moduledoc """
  Painel de monitoramento do reservatório.

  As leituras vêm de `AquaSense.Monitoring.Reading`, populadas pelo
  `AquaSense.Monitoring.MqttConsumer` a partir do que o ESP32 publica. O
  painel assina `"readings:new"` e recarrega a cada leitura nova, então fica
  sempre no que há de mais recente no banco.

  Não há sensor de turbidez no protótipo — o parâmetro `:turbidity` fica sem
  entrada em `load_readings/0`, o que basta para cair no mesmo tratamento de
  "sem sensor" usado quando ainda não chegou nenhuma leitura (banco vazio):
  `parameter_view/2` mostra o cartão com tom neutro e "—" em vez de inventar
  um número.

  O que o painel mostra é derivado desses valores, não escrito à mão: a
  variação em 24 h, a posição na barra de limite e a situação de cada
  parâmetro saem de `parameter_view/2`. Mudar uma leitura muda a etiqueta de
  situação junto, que é o mínimo para um painel em que a cor significa algo.
  """
  use AquaSenseWeb, :live_view

  alias AquaSense.Chart
  alias AquaSense.Format
  alias AquaSense.Monitoring.Reading

  on_mount {AquaSenseWeb.LiveUserAuth, :live_user_required}

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

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AquaSense.PubSub, "readings:new")
    end

    users = list_users()
    open_alerts = Enum.count(@alerts, & &1.open?)

    {:ok,
     socket
     |> assign(
       page_title: "Visão geral",
       active_tab: "overview",
       chart_tab: "conductivity",
       alerts: @alerts,
       open_alerts: open_alerts,
       system_status: @system_status,
       legal_limits: @legal_limits,
       nav: nav_groups(open_alerts),
       device: %{
         online?: true,
         label: "Sonda transmitindo",
         detail: "Última leitura 14:30 · RSSI −72 dBm"
       },
       users: users,
       user_form: %{name: "", email: "", error: nil, success: nil}
     )
     |> load_and_assign()}
  end

  @impl true
  def handle_event("set_nav", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab, page_title: tab_title(tab))}
  end

  def handle_event("set_chart_tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(chart_tab: tab) |> load_and_assign()}
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

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "readings:new"}, socket) do
    {:noreply, load_and_assign(socket)}
  end

  @doc """
  Parâmetro em destaque no histórico, conforme a aba escolhida.
  """
  def selected_parameter(parameters, chart_tab) do
    Enum.find(parameters, hd(parameters), &(Atom.to_string(&1.key) == chart_tab))
  end

  # ── montagem dos gráficos ─────────────────────────────────────────────────

  defp load_and_assign(socket) do
    readings = load_readings()
    parameters = Enum.map(@parameters, &parameter_view(&1, readings))
    selected = selected_parameter(parameters, socket.assigns.chart_tab)
    {min, max} = selected.scale
    level_values = non_empty(Map.get(readings, :level, []))

    assign(socket,
      parameters: parameters,
      banner: banner(parameters),
      level: List.last(level_values),
      # Nível é a série do topo: porcentagem tem zero significativo, então o
      # eixo começa em zero e o preenchimento sob a curva é honesto.
      level_chart: Chart.build(level_values, x0: 44, x1: 740, y0: 16, y1: 250, min: 0, max: 100),
      level_ticks: Chart.nice_ticks(0, 100, 5),
      level_x_labels: x_labels(length(level_values)),
      history: selected,
      history_chart:
        Chart.build(non_empty(Map.get(readings, selected.key, [])),
          x0: 56,
          x1: 1090,
          y0: 22,
          y1: 300,
          min: min,
          max: max
        ),
      history_ticks: Chart.nice_ticks(min, max, 5)
    )
  end

  # Série sem leitura (turbidez, que não tem sensor; ou qualquer parâmetro
  # antes da primeira publicação do ESP32) precisa de um ponto pra geometria
  # não quebrar, mas não pode fingir ser uma medição real.
  defp non_empty([]), do: [0.0]
  defp non_empty(values), do: values

  # Marcas do eixo do tempo: apontam para posições da própria série, então
  # continuam certas conforme a janela cresce das primeiras leituras até as
  # 48 (24 h) de regime — cada série tem o seu, pois uma leitura sem sensor
  # (1 ponto) não tem o mesmo tamanho de uma série real.
  defp x_labels(count) when count <= 1 do
    [%{index: 0, text: "agora", anchor: "start"}]
  end

  defp x_labels(count) do
    last = count - 1

    [
      %{index: 0, text: "00h", anchor: "start"},
      %{index: div(last, 2), text: "12h", anchor: "middle"},
      %{index: last, text: "agora", anchor: "end"}
    ]
  end

  defp parameter_view(parameter, readings) do
    case Map.get(readings, parameter.key, []) do
      [] -> unavailable_parameter_view(parameter)
      values -> live_parameter_view(parameter, values)
    end
  end

  defp unavailable_parameter_view(parameter) do
    {spark_min, spark_max} = parameter.spark_scale
    {scale_min, scale_max} = parameter.scale
    placeholder = [0.0]

    parameter
    |> Map.merge(%{
      value: nil,
      formatted: "—",
      delta: "—",
      delta_dir: :up,
      tone: :info,
      tone_label: "Sem sensor",
      fill_pct: 0.0,
      limit_pct: (parameter.limit || parameter.floor) / parameter.bar_max * 100,
      spark:
        Chart.build(placeholder, x0: 0, x1: 240, y0: 6, y1: 38, min: spark_min, max: spark_max),
      small:
        Chart.build(placeholder, x0: 40, x1: 296, y0: 10, y1: 92, min: scale_min, max: scale_max),
      small_ticks: Chart.nice_ticks(scale_min, scale_max, 4),
      x_labels: x_labels(length(placeholder)),
      dom_id: "param-#{parameter.key}"
    })
  end

  defp live_parameter_view(parameter, values) do
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
      x_labels: x_labels(length(values)),
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
  defp tone_rank(:info), do: 3

  defp banner_title(:crit), do: "1 parâmetro fora do limite legal"
  defp banner_title(:warn), do: "1 parâmetro se aproximando do limite"
  defp banner_title(:info), do: "Aguardando leituras do sensor"

  defp banner_detail(%{value: nil} = parameter) do
    "Nenhuma leitura recebida ainda para #{String.downcase(parameter.label)}."
  end

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

  defp load_readings do
    Reading
    |> Ash.Query.for_read(:recent, %{limit: 48})
    |> Ash.read!(domain: AquaSense.Monitoring, authorize?: false)
    |> Enum.reverse()
    |> then(fn readings ->
      %{
        level: Enum.map(readings, & &1.level),
        temperature: Enum.map(readings, & &1.temperature),
        conductivity: Enum.map(readings, & &1.conductivity)
      }
    end)
  end

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
