defmodule AquaSenseWeb.DashboardLive do
  use AquaSenseWeb, :live_view

  on_mount {AquaSenseWeb.LiveUserAuth, :live_user_required}

  @water_level_hist  [65, 68, 70, 72, 71, 73, 75, 74, 76, 77, 76, 78, 79, 77, 78, 79, 78, 77, 78, 79, 78, 78, 78, 78]
  @temp_hist         [23.1, 23.2, 23.4, 23.6, 23.8, 24.0, 24.1, 24.2, 24.3, 24.4, 24.4, 24.3, 24.3, 24.2, 24.2, 24.3, 24.3, 24.3, 24.3, 24.3, 24.3, 24.3, 24.3, 24.3]
  @turbidity_hist    [2.1, 2.2, 2.3, 2.5, 2.7, 2.9, 3.0, 3.1, 3.2, 3.1, 3.0, 3.1, 3.2, 3.2, 3.1, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2, 3.2]
  @conductivity_hist [295, 298, 300, 302, 305, 307, 308, 309, 310, 311, 311, 312, 312, 311, 312, 312, 312, 312, 312, 312, 312, 312, 312, 312]

  @chart_histories %{
    "level"        => @water_level_hist,
    "temperature"  => @temp_hist,
    "turbidity"    => @turbidity_hist,
    "conductivity" => @conductivity_hist
  }

  def mount(_params, _session, socket) do
    users = AquaSense.Accounts.User |> Ash.read!(domain: AquaSense.Accounts, authorize?: false)

    {:ok,
     assign(socket,
       metrics: %{
         water_level: 78,
         temperature: 24.3,
         turbidity: 3.2,
         conductivity: 312
       },
       alerts: [
         %{id: 1, severity: :warning, message: "Condutividade acima do recomendado (312 μS/cm)", time: "5 min atrás"},
         %{id: 2, severity: :info, message: "Nível de água normalizado após recarga", time: "2h atrás"},
         %{id: 3, severity: :error, message: "Sensor de turbidez offline por 3 min", time: "4h atrás"},
         %{id: 4, severity: :success, message: "Parâmetros dentro dos limites da Portaria 888/2021", time: "6h atrás"}
       ],
       system_status: [
         %{name: "ESP32", status: :online, detail: "Firmware v2.1.3"},
         %{name: "Broker MQTT", status: :online, detail: "mosquitto 2.0.18"},
         %{name: "PostgreSQL", status: :online, detail: "v15.4 — 2.3 GB"},
         %{name: "Backend Elixir", status: :online, detail: "Phoenix 1.8 / Ash 3.0"},
         %{name: "Rede WiFi", status: :warning, detail: "RSSI: −72 dBm"}
       ],
       users: users,
       user_form: %{name: "", email: "", password: "", error: nil, success: nil},
       active_tab: "overview",
       chart_tab: "level",
       sparklines: %{
         level: sparkline(@water_level_hist),
         temperature: sparkline(@temp_hist),
         turbidity: sparkline(@turbidity_hist),
         conductivity: sparkline(@conductivity_hist)
       },
       chart: build_chart(@water_level_hist)
     )}
  end

  def handle_event("set_nav", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("set_chart_tab", %{"tab" => tab}, socket) do
    history = Map.fetch!(@chart_histories, tab)
    {:noreply, assign(socket, chart_tab: tab, chart: build_chart(history))}
  end

  def handle_event("create_user", %{"name" => name, "email" => email, "password" => password}, socket) do
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
        # Auto-confirma usuários criados pelo admin
        user
        |> Ash.Changeset.for_update(:confirm_user, %{})
        |> Ash.update(domain: AquaSense.Accounts, authorize?: false)

        users = AquaSense.Accounts.User |> Ash.read!(domain: AquaSense.Accounts, authorize?: false)
        form = %{name: "", email: "", password: "", error: nil, success: "Usuário criado com sucesso!"}
        {:noreply, assign(socket, users: users, user_form: form)}

      {:error, error} ->
        msg = user_error_message(error)
        form = %{socket.assigns.user_form | error: msg, success: nil}
        {:noreply, assign(socket, user_form: form)}
    end
  end

  def handle_event("confirm_user", %{"id" => id}, socket) do
    case AquaSense.Accounts.User
         |> Ash.get!(id, domain: AquaSense.Accounts, authorize?: false)
         |> Ash.Changeset.for_update(:confirm_user, %{})
         |> Ash.update(domain: AquaSense.Accounts, authorize?: false) do
      {:ok, _} ->
        users = AquaSense.Accounts.User |> Ash.read!(domain: AquaSense.Accounts, authorize?: false)
        {:noreply, assign(socket, users: users)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp user_error_message(%{errors: [first | _]}) do
    case first do
      %{message: msg} -> msg
      %{messages: [msg | _]} -> msg
      _ -> "Erro ao criar usuário."
    end
  end

  defp user_error_message(_), do: "Erro ao criar usuário."

  defp sparkline(values) do
    n = length(values)
    max_v = Enum.max(values)
    min_v = Enum.min(values)
    range = max(max_v - min_v, 0.001)

    values
    |> Enum.with_index()
    |> Enum.map(fn {v, i} ->
      x = Float.round(i * 100.0 / (n - 1), 1)
      y = Float.round(28 - (v - min_v) / range * 24, 1)
      "#{x},#{y}"
    end)
    |> Enum.join(" ")
  end

  defp build_chart(values) do
    n = length(values)
    w = 520
    h = 150
    px = 8
    py = 10
    max_v = Enum.max(values)
    min_v = Enum.min(values)
    range = max(max_v - min_v, 0.001)

    pts =
      values
      |> Enum.with_index()
      |> Enum.map(fn {v, i} ->
        x = Float.round(px + i * (w - px * 2.0) / (n - 1), 1)
        y = Float.round(h - py - (v - min_v) / range * (h - py * 2), 1)
        {x, y}
      end)

    poly = pts |> Enum.map(fn {x, y} -> "#{x},#{y}" end) |> Enum.join(" ")
    {x0, _} = hd(pts)
    {xn, _} = List.last(pts)
    area = "M #{x0},#{h - py} L #{poly} L #{xn},#{h - py} Z"

    %{polyline: poly, area: area}
  end

  def alert_bg_class(:warning), do: "bg-yellow-500/10"
  def alert_bg_class(:error),   do: "bg-red-500/10"
  def alert_bg_class(:info),    do: "bg-sky-500/10"
  def alert_bg_class(:success), do: "bg-green-500/10"

  def alert_dot_class(:warning), do: "bg-yellow-400"
  def alert_dot_class(:error),   do: "bg-red-400"
  def alert_dot_class(:info),    do: "bg-sky-400"
  def alert_dot_class(:success), do: "bg-green-400"

  def alert_badge_class(:warning), do: "bg-yellow-500/20 text-yellow-400"
  def alert_badge_class(:error),   do: "bg-red-500/20 text-red-400"
  def alert_badge_class(:info),    do: "bg-sky-500/20 text-sky-400"
  def alert_badge_class(:success), do: "bg-green-500/20 text-green-400"

  def alert_label(:warning), do: "Atenção"
  def alert_label(:error),   do: "Crítico"
  def alert_label(:info),    do: "Info"
  def alert_label(:success), do: "OK"

  def status_dot_class(:online),  do: "bg-green-400"
  def status_dot_class(:warning), do: "bg-yellow-400"
  def status_dot_class(:offline), do: "bg-red-400"

  def status_text_class(:online),  do: "text-green-400"
  def status_text_class(:warning), do: "text-yellow-400"
  def status_text_class(:offline), do: "text-red-400"

  def status_label(:online),  do: "Online"
  def status_label(:warning), do: "Instável"
  def status_label(:offline), do: "Offline"

  def alert_bg_hex(:warning), do: "#422006aa"
  def alert_bg_hex(:error),   do: "#450a0aaa"
  def alert_bg_hex(:info),    do: "#0c1a2eaa"
  def alert_bg_hex(:success), do: "#052e16aa"

  def alert_dot_hex(:warning), do: "#fbbf24"
  def alert_dot_hex(:error),   do: "#f87171"
  def alert_dot_hex(:info),    do: "#38bdf8"
  def alert_dot_hex(:success), do: "#4ade80"

  def alert_badge_bg_hex(:warning), do: "#45260233"
  def alert_badge_bg_hex(:error),   do: "#450a0a33"
  def alert_badge_bg_hex(:info),    do: "#0c4a6e33"
  def alert_badge_bg_hex(:success), do: "#14532d33"

  def status_dot_hex(:online),  do: "#4ade80"
  def status_dot_hex(:warning), do: "#fbbf24"
  def status_dot_hex(:offline), do: "#f87171"
end
