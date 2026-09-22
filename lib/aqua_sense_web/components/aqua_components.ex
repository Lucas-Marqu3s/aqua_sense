defmodule AquaSenseWeb.AquaComponents do
  @moduledoc """
  Peças visuais do AquaSense: cartões de leitura, gráficos, tanque e avisos.

  Três regras valem para tudo aqui e explicam a forma dos componentes:

    * **Um eixo por gráfico.** Grandezas de unidades diferentes nunca se
      sobrepõem no mesmo par de eixos — viram vários gráficos pequenos com a
      linha do tempo compartilhada.
    * **A cor segue o parâmetro.** Nível é azul, temperatura laranja, turbidez
      violeta, condutividade magenta, em qualquer tela. Quem escolhe é o
      atributo `series`, que só define a variável CSS `--as-series`.
    * **Cor de situação é reservada.** Verde, âmbar e vermelho indicam apenas
      situação, nunca uma série, e sempre vêm com ícone e palavra.

  Nenhum componente escreve cor em hexadecimal: tudo sai dos tokens em
  `assets/css/app.css`, o que faz o tema claro e o escuro saírem de graça.
  """

  use Phoenix.Component

  import AquaSenseWeb.CoreComponents, only: [icon: 1]

  alias AquaSense.Chart
  alias AquaSense.Format

  @doc """
  Etiqueta de situação. Sempre ícone + palavra, nunca só a cor.
  """
  attr :tone, :atom, default: :ok, values: [:ok, :warn, :crit, :info]
  attr :label, :string, required: true
  attr :class, :any, default: nil

  def status_chip(assigns) do
    ~H"""
    <span class={["as-chip as-chip-tone", tone_class(@tone), @class]}>
      <.icon name={tone_icon(@tone)} class="size-3 shrink-0" />
      {@label}
    </span>
    """
  end

  @doc """
  Linha fina de 24 h usada dentro do cartão de leitura.

  Recebe a geometria já pronta. Se `limit` for informado e couber na escala,
  desenha o tracejado do limite legal junto.
  """
  attr :id, :string, required: true
  attr :chart, Chart, required: true
  attr :width, :integer, required: true
  attr :height, :integer, required: true
  attr :limit, :float, default: nil

  def sparkline(assigns) do
    assigns = assign(assigns, :last, Chart.last_point(assigns.chart))

    ~H"""
    <svg
      id={@id}
      viewBox={"0 0 #{@width} #{@height}"}
      width={@width}
      height={@height}
      aria-hidden="true"
      class="block w-full"
    >
      <defs>
        <linearGradient id={"#{@id}-fill"} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="var(--as-series)" stop-opacity="0.24" />
          <stop offset="100%" stop-color="var(--as-series)" stop-opacity="0" />
        </linearGradient>
      </defs>
      <line
        :if={@limit && within?(@chart, @limit)}
        x1={@chart.x0}
        y1={Chart.y(@chart, @limit)}
        x2={@chart.x1}
        y2={Chart.y(@chart, @limit)}
        stroke="var(--as-crit-mark)"
        stroke-width="1"
        stroke-dasharray="4 4"
      />
      <path d={@chart.area} fill={"url(##{@id}-fill)"} />
      <path
        d={@chart.line}
        fill="none"
        stroke="var(--as-series)"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <circle
        cx={@last.x}
        cy={@last.y}
        r="3.5"
        fill="var(--as-series)"
        stroke="var(--as-surface)"
        stroke-width="2"
      />
    </svg>
    """
  end

  @doc """
  Gráfico de linha com eixo rotulado, faixa de limite e rótulo direto.

  O eixo Y sempre carrega a unidade: número solto não diz nada. `x_labels`
  recebe uma lista de `%{index:, text:, anchor:}` apontando para posições da
  própria série, então os rótulos nunca saem do lugar se a série mudar de
  tamanho.
  """
  attr :id, :string, required: true
  attr :chart, Chart, required: true
  attr :width, :integer, required: true
  attr :height, :integer, required: true
  attr :label, :string, required: true, doc: "descrição da série para leitor de tela"
  attr :unit, :string, default: nil
  attr :ticks, :list, default: []
  attr :decimals, :integer, default: 0
  attr :x_labels, :list, default: []
  attr :limit, :float, default: nil
  attr :limit_label, :string, default: nil
  attr :limit_side, :atom, default: :above, values: [:above, :below]
  attr :annotation, :map, default: nil, doc: "%{index:, text:} para marcar um evento"
  attr :marker_label, :string, default: nil
  attr :fill, :boolean, default: true

  def line_chart(assigns) do
    assigns = assign(assigns, :last, Chart.last_point(assigns.chart))

    ~H"""
    <svg
      id={@id}
      viewBox={"0 0 #{@width} #{@height}"}
      width={@width}
      height={@height}
      role="img"
      aria-label={@label}
      class="block w-full"
    >
      <defs>
        <linearGradient id={"#{@id}-fill"} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="var(--as-series)" stop-opacity="0.28" />
          <stop offset="100%" stop-color="var(--as-series)" stop-opacity="0.02" />
        </linearGradient>
      </defs>

      <%!-- Faixa fora do limite legal: o olho vê a zona proibida antes de ler o número --%>
      <g :if={@limit && within?(@chart, @limit)}>
        <rect
          x={@chart.x0}
          y={limit_band_y(@chart, @limit, @limit_side)}
          width={@chart.x1 - @chart.x0}
          height={limit_band_height(@chart, @limit, @limit_side)}
          fill="var(--as-crit-mark)"
          opacity="0.09"
        />
        <line
          x1={@chart.x0}
          y1={Chart.y(@chart, @limit)}
          x2={@chart.x1}
          y2={Chart.y(@chart, @limit)}
          stroke="var(--as-crit-mark)"
          stroke-width="1.5"
          stroke-dasharray="6 4"
        />
        <text
          :if={@limit_label}
          x={@chart.x1 - 8}
          y={limit_label_y(@chart, @limit, @limit_side)}
          text-anchor="end"
          class="fill-crit font-mono text-[10.5px] font-semibold"
        >
          {@limit_label}
        </text>
      </g>

      <g :for={tick <- @ticks}>
        <line
          x1={@chart.x0}
          y1={Chart.y(@chart, tick)}
          x2={@chart.x1}
          y2={Chart.y(@chart, tick)}
          stroke="var(--as-grid)"
          stroke-width="1"
        />
        <text
          x={@chart.x0 - 10}
          y={Chart.y(@chart, tick) + 3.5}
          text-anchor="end"
          class="fill-ink-3 font-mono text-[10.5px]"
        >
          {Format.number(tick, @decimals)}
        </text>
      </g>

      <text
        :if={@unit}
        x={@chart.x0 - 10}
        y={@chart.y0 - 6}
        text-anchor="end"
        class="fill-ink-3 font-mono text-[10px]"
      >
        {@unit}
      </text>

      <g :if={@annotation}>
        <line
          x1={Chart.x(@chart, @annotation.index)}
          y1={@chart.y0}
          x2={Chart.x(@chart, @annotation.index)}
          y2={@chart.y1}
          stroke="var(--as-ink-3)"
          stroke-width="1"
          stroke-dasharray="3 4"
        />
        <text
          x={Chart.x(@chart, @annotation.index) + 7}
          y={@chart.y0 + 13}
          class="fill-ink-2 text-[10.5px] font-semibold"
        >
          {@annotation.text}
        </text>
      </g>

      <path :if={@fill} d={@chart.area} fill={"url(##{@id}-fill)"} />
      <path
        d={@chart.line}
        fill="none"
        stroke="var(--as-series)"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />

      <circle
        cx={@last.x}
        cy={@last.y}
        r="4.5"
        fill="var(--as-series)"
        stroke="var(--as-surface)"
        stroke-width="2.5"
      />
      <text
        :if={@marker_label}
        x={@last.x - 10}
        y={@last.y - 12}
        text-anchor="end"
        class="fill-ink font-mono text-[13px] font-semibold"
      >
        {@marker_label}
      </text>

      <line
        x1={@chart.x0}
        y1={@chart.y1}
        x2={@chart.x1}
        y2={@chart.y1}
        stroke="var(--as-axis)"
        stroke-width="1"
      />
      <text
        :for={label <- @x_labels}
        x={Chart.x(@chart, label.index)}
        y={@chart.y1 + 18}
        text-anchor={label.anchor}
        class="fill-ink-3 font-mono text-[10.5px]"
      >
        {label.text}
      </text>
    </svg>
    """
  end

  @doc """
  Cartão de leitura: valor, variação em 24 h, faixa contra o limite e a
  série das últimas 24 h.

  O número nunca aparece sozinho — ao lado dele vem sempre o limite legal ou
  a faixa aceitável, que é o que torna a leitura interpretável.
  """
  attr :id, :string, required: true
  attr :series, :atom, required: true, values: [:level, :temp, :turb, :cond]
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :unit, :string, required: true
  attr :icon, :string, required: true
  attr :delta, :string, required: true
  attr :delta_dir, :atom, default: :up, values: [:up, :down]
  attr :tone, :atom, default: :ok, values: [:ok, :warn, :crit]
  attr :tone_label, :string, required: true
  attr :chart, Chart, required: true
  attr :limit, :float, default: nil
  attr :limit_label, :string, required: true
  attr :fill_pct, :float, required: true, doc: "posição do valor na barra, 0 a 100"
  attr :limit_pct, :float, required: true, doc: "posição do limite na barra, 0 a 100"

  def metric_card(assigns) do
    ~H"""
    <div class={["as-card p-4 flex flex-col gap-3", series_class(@series), tone_class(@tone)]}>
      <div class="flex items-center gap-2">
        <.icon name={@icon} class="size-4 shrink-0 text-[var(--as-series)]" />
        <span class="as-eyebrow grow">{@label}</span>
        <.status_chip tone={@tone} label={@tone_label} />
      </div>

      <div class="flex items-baseline gap-1.5">
        <span class="as-num text-3xl font-semibold leading-none text-ink">{@value}</span>
        <span class="text-[13px] font-medium text-ink-2">{@unit}</span>
        <span class="ml-auto inline-flex items-center gap-1 text-xs text-ink-2">
          <.icon
            name={if(@delta_dir == :up, do: "hero-arrow-up", else: "hero-arrow-down")}
            class="size-3.5 shrink-0"
          />
          <span class="as-num">{@delta}</span>
        </span>
      </div>

      <.sparkline id={@id} chart={@chart} width={240} height={44} limit={@limit} />

      <div class="flex flex-col gap-1.5">
        <div class="relative h-[18px]">
          <div class="absolute inset-x-0 top-[6px] h-1.5 rounded-full bg-inset border border-hairline">
          </div>
          <div
            class="absolute left-0 top-[6px] h-1.5 rounded-full bg-[var(--as-series)]"
            style={"width:#{clamp_pct(@fill_pct)}%"}
          >
          </div>
          <div
            class="absolute top-0 h-[18px] w-0.5 rounded-sm bg-[var(--as-tone)]"
            style={"left:#{clamp_pct(@limit_pct)}%"}
          >
          </div>
        </div>
        <div class="flex justify-between text-[11px] text-ink-3">
          <span>24 h</span>
          <span class="as-num">{@limit_label}</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Coluna de medição do reservatório, com a régua e a zona abaixo do mínimo.
  """
  attr :id, :string, required: true
  attr :level, :float, required: true
  attr :min_level, :float, default: 20.0
  attr :capacity, :integer, required: true

  def tank(assigns) do
    assigns =
      assign(assigns,
        volume: round(assigns.capacity * assigns.level / 100),
        scale: Chart.build([0, 100], x0: 0, x1: 1, y0: 24, y1: 300, min: 0, max: 100)
      )

    ~H"""
    <svg
      viewBox="0 0 300 330"
      width="300"
      height="330"
      role="img"
      aria-label={"Reservatório em #{Format.number(@level, 1)}% da capacidade, mínimo operacional em #{Format.number(@min_level, 0)}%."}
      class="as-s-level block"
    >
      <defs>
        <linearGradient id={"#{@id}-water"} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="var(--as-series)" stop-opacity="0.62" />
          <stop offset="100%" stop-color="var(--as-series)" stop-opacity="0.30" />
        </linearGradient>
        <clipPath id={"#{@id}-clip"}>
          <rect x="96" y="24" width="100" height="276" rx="8" />
        </clipPath>
      </defs>

      <rect x="96" y="24" width="100" height="276" rx="8" fill="var(--as-inset)" />

      <g clip-path={"url(##{@id}-clip)"}>
        <rect
          x="96"
          y={Chart.y(@scale, @min_level)}
          width="100"
          height={300 - Chart.y(@scale, @min_level)}
          fill="var(--as-crit-mark)"
          opacity="0.13"
        />
        <rect
          x="96"
          y={Chart.y(@scale, @level)}
          width="100"
          height={300 - Chart.y(@scale, @level)}
          fill={"url(##{@id}-water)"}
        />
        <line
          x1="96"
          y1={Chart.y(@scale, @level)}
          x2="196"
          y2={Chart.y(@scale, @level)}
          stroke="var(--as-series)"
          stroke-width="2"
        />
      </g>

      <rect
        x="96"
        y="24"
        width="100"
        height="276"
        rx="8"
        fill="none"
        stroke="var(--as-line-2)"
        stroke-width="1.5"
      />

      <g :for={mark <- [0, 20, 40, 60, 80, 100]}>
        <line
          x1="89"
          y1={Chart.y(@scale, mark)}
          x2="96"
          y2={Chart.y(@scale, mark)}
          stroke="var(--as-axis)"
          stroke-width="1.25"
        />
        <text
          x="84"
          y={Chart.y(@scale, mark) + 3.5}
          text-anchor="end"
          class="fill-ink-3 font-mono text-[10.5px]"
        >
          {mark}%
        </text>
      </g>

      <line
        x1="96"
        y1={Chart.y(@scale, @min_level)}
        x2="196"
        y2={Chart.y(@scale, @min_level)}
        stroke="var(--as-crit-mark)"
        stroke-width="1.25"
        stroke-dasharray="4 3"
      />
      <text
        x="204"
        y={Chart.y(@scale, @min_level) + 3.5}
        class="fill-crit font-mono text-[10px] font-semibold"
      >
        MÍN.
      </text>

      <line
        x1="196"
        y1={Chart.y(@scale, @level)}
        x2="212"
        y2={Chart.y(@scale, @level)}
        stroke="var(--as-series)"
        stroke-width="1.25"
      />
      <text x="204" y={Chart.y(@scale, @level) - 9} class="fill-ink font-mono text-base font-semibold">
        {Format.number(@level, 1)}%
      </text>
      <text x="204" y={Chart.y(@scale, @level) + 18} class="fill-ink-3 font-mono text-[10.5px]">
        {Format.thousands(@volume)} L
      </text>
    </svg>
    """
  end

  @doc """
  Faixa de veredito no topo do painel: responde "está tudo bem?" antes de
  qualquer número.
  """
  attr :tone, :atom, default: :ok, values: [:ok, :warn, :crit]
  attr :title, :string, required: true
  attr :meta, :string, default: nil
  slot :detail
  slot :actions

  def status_banner(assigns) do
    ~H"""
    <div
      role="status"
      class={[
        "flex items-center gap-3.5 rounded-xl border p-3.5",
        "border-[var(--as-tone)] bg-[var(--as-tone-tint)]",
        tone_class(@tone)
      ]}
    >
      <span class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-surface text-[var(--as-tone)]">
        <.icon name={tone_icon(@tone)} class="size-5" />
      </span>
      <div class="min-w-0 grow">
        <p class="text-sm font-semibold text-ink">{@title}</p>
        <p :if={@detail != []} class="mt-0.5 text-[12.5px] text-ink-2">{render_slot(@detail)}</p>
      </div>
      <span :if={@meta} class="as-num shrink-0 text-[11.5px] text-ink-2">{@meta}</span>
      <div :if={@actions != []} class="shrink-0">{render_slot(@actions)}</div>
    </div>
    """
  end

  @doc """
  Item da lista de alertas.
  """
  attr :tone, :atom, default: :info, values: [:ok, :warn, :crit, :info]
  attr :title, :string, required: true
  attr :badge, :string, required: true
  attr :meta, :string, required: true
  attr :class, :any, default: nil
  slot :detail
  slot :actions

  def alert_item(assigns) do
    ~H"""
    <article class={["flex gap-3", tone_class(@tone), @class]}>
      <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-[var(--as-tone-tint)] text-[var(--as-tone)]">
        <.icon name={tone_icon(@tone)} class="size-4" />
      </span>
      <div class="min-w-0 grow">
        <div class="flex flex-wrap items-center gap-2">
          <p class="text-[13.5px] font-semibold text-ink">{@title}</p>
          <span class="as-chip as-chip-tone h-5 text-[10.5px]">{@badge}</span>
        </div>
        <p :if={@detail != []} class="mt-1 text-[12.5px] leading-relaxed text-ink-2">
          {render_slot(@detail)}
        </p>
        <div class="mt-1.5 flex flex-wrap items-center gap-3">
          <span class="as-num text-[11.5px] text-ink-3">{@meta}</span>
          <div :if={@actions != []} class="ml-auto flex gap-2">{render_slot(@actions)}</div>
        </div>
      </div>
    </article>
    """
  end

  @doc """
  A figura do poço, usada nas telas de entrada.

  Desenho de linha: uma espessura, duas cores, sem textura e sem rótulo
  dentro da arte. Quem descreve a cena é o `<title>`, que o leitor de tela lê
  e o olho não vê.
  """
  attr :class, :any, default: nil

  def well_figure(assigns) do
    ~H"""
    <svg
      viewBox="0 0 460 330"
      role="img"
      aria-labelledby="figura-poco"
      class={["as-s-level block w-full max-w-[560px]", @class]}
    >
      <title id="figura-poco">
        Poço perfurado até o aquífero, com a sonda submersa transmitindo as leituras para a superfície.
      </title>

      <%!-- água: um preenchimento único, sem textura --%>
      <rect x="0" y="168" width="460" height="132" fill="var(--as-series)" opacity="0.07" />

      <%!-- terreno e base rochosa --%>
      <line x1="0" y1="100" x2="460" y2="100" stroke="var(--as-line-2)" stroke-width="1.25" />
      <line x1="0" y1="300" x2="460" y2="300" stroke="var(--as-line-2)" stroke-width="1.25" />

      <%!-- lençol freático --%>
      <line x1="0" y1="168" x2="460" y2="168" stroke="var(--as-series)" stroke-width="1.5" />

      <%!-- poço --%>
      <line x1="216" y1="84" x2="216" y2="272" stroke="var(--as-line-2)" stroke-width="1.25" />
      <line x1="244" y1="84" x2="244" y2="272" stroke="var(--as-line-2)" stroke-width="1.25" />
      <rect
        x="212"
        y="74"
        width="36"
        height="11"
        rx="3"
        fill="none"
        stroke="var(--as-line-2)"
        stroke-width="1.25"
      />

      <%!-- cabo e sonda --%>
      <line x1="230" y1="85" x2="230" y2="236" stroke="var(--as-line-2)" stroke-width="1" />
      <rect x="222" y="236" width="16" height="34" rx="8" fill="var(--as-series)" />

      <%!-- transmissão --%>
      <path
        d="M206 64 a30 30 0 0 1 48 0"
        fill="none"
        stroke="var(--as-series)"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <path
        d="M194 52 a44 44 0 0 1 72 0"
        fill="none"
        stroke="var(--as-series)"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  @doc """
  Classe que define `--as-series` para um parâmetro.

  Útil em blocos do template que não são um componente daqui mas precisam
  pintar com a cor do parâmetro — um marcador de legenda, por exemplo.

      <div class={series_class(:cond)}>
        <span class="bg-[var(--as-series)]"></span>
      </div>
  """
  def series_class(:level), do: "as-s-level"
  def series_class(:temp), do: "as-s-temp"
  def series_class(:turb), do: "as-s-turb"
  def series_class(:cond), do: "as-s-cond"

  @doc """
  Classe que define `--as-tone`, `--as-tone-text` e `--as-tone-tint` para uma
  situação.
  """
  def tone_class(:ok), do: "as-tone-ok"
  def tone_class(:warn), do: "as-tone-warn"
  def tone_class(:crit), do: "as-tone-crit"
  def tone_class(:info), do: "as-tone-info"

  # ── auxiliares ────────────────────────────────────────────────────────────

  defp tone_icon(:ok), do: "hero-check-circle"
  defp tone_icon(:warn), do: "hero-exclamation-triangle"
  defp tone_icon(:crit), do: "hero-x-circle"
  defp tone_icon(:info), do: "hero-information-circle"

  # O limite só vale desenhar se couber na escala; fora dela viraria uma régua
  # colada na borda, dizendo menos do que nada.
  defp within?(%Chart{min: min, max: max}, value), do: value >= min and value <= max

  defp limit_band_y(chart, _limit, :above), do: chart.y0
  defp limit_band_y(chart, limit, :below), do: Chart.y(chart, limit)

  defp limit_band_height(chart, limit, :above), do: Chart.y(chart, limit) - chart.y0
  defp limit_band_height(chart, limit, :below), do: chart.y1 - Chart.y(chart, limit)

  defp limit_label_y(chart, limit, _side), do: Chart.y(chart, limit) - 9

  defp clamp_pct(value) when is_number(value) do
    (value * 1.0) |> max(0.0) |> min(100.0) |> Float.round(1)
  end
end
