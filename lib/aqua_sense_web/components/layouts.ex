defmodule AquaSenseWeb.Layouts do
  @moduledoc """
  Layouts da aplicação.

  `app/1` tem duas formas. A padrão, `:shell`, é o painel logado: barra
  lateral fixa, cabeçalho com título e ações, e o conteúdo rolando por
  dentro. A forma `:bare` entrega só o conteúdo e o grupo de flash, para as
  telas de entrada, que trazem a própria composição de duas colunas.

  Toda tela passa por aqui — é o que garante que as mensagens de flash
  apareçam em qualquer lugar sem o template precisar lembrar disso.
  """
  use AquaSenseWeb, :html

  embed_templates "layouts/*"

  @doc """
  Casca da aplicação.

  ## Exemplos

      <Layouts.app flash={@flash} variant={:bare}>
        <.minha_tela />
      </Layouts.app>

      <Layouts.app flash={@flash} current_user={@current_user} active={:overview} title="Visão geral">
        <:actions><button class="as-btn as-btn-ghost">Exportar</button></:actions>
        <.conteudo />
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "o mapa de mensagens de flash"
  attr :variant, :atom, default: :shell, values: [:shell, :bare]
  attr :current_user, :map, default: nil
  attr :active, :string, default: nil, doc: "id do item de navegação em destaque"
  attr :title, :string, default: nil
  attr :subtitle, :string, default: nil
  attr :crumb, :string, default: nil

  attr :nav, :list,
    default: [],
    doc: """
    grupos da lateral, na ordem em que aparecem:
    `[%{label: "Monitoramento", items: [%{id:, label:, icon:, badge:}]}]`
    """

  attr :nav_event, :string,
    default: "set_nav",
    doc: "evento disparado ao clicar num item da lateral"

  attr :device, :map, default: nil, doc: "%{online?:, label:, detail:} do rodapé da lateral"

  slot :actions
  slot :inner_block, required: true

  def app(%{variant: :bare} = assigns) do
    ~H"""
    {render_slot(@inner_block)}
    <.flash_group flash={@flash} />
    """
  end

  def app(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden bg-canvas text-ink">
      <aside class="flex w-[244px] shrink-0 flex-col border-r border-hairline bg-surface">
        <div class="flex items-center gap-2.5 border-b border-hairline px-4 py-4.5">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-level text-white">
            <.icon name="hero-beaker" class="size-4.5" />
          </span>
          <span class="min-w-0">
            <span class="block text-[14.5px] font-bold tracking-tight">AquaSense</span>
            <span class="block text-[11px] text-ink-3">Poço PT-01 · Campus</span>
          </span>
        </div>

        <nav class="flex grow flex-col gap-0.5 overflow-y-auto px-3 py-3.5">
          <%= for group <- @nav do %>
            <p class="as-eyebrow px-3 pt-3.5 pb-1.5 first:pt-1.5">{group.label}</p>
            <button
              :for={item <- group.items}
              type="button"
              class="as-nav-item"
              aria-current={@active == item.id && "page"}
              phx-click={@nav_event}
              phx-value-tab={item.id}
            >
              <.icon name={item.icon} class="size-4.5 shrink-0" />
              <span class="grow">{item.label}</span>
              <span :if={item[:badge]} class="as-chip as-chip-tone as-tone-crit h-5 px-1.5 text-[10.5px]">
                {item.badge}
              </span>
            </button>
          <% end %>
        </nav>

        <div class="flex flex-col gap-2.5 border-t border-hairline p-3">
          <div :if={@device} class="rounded-lg border border-hairline bg-inset p-2.5">
            <p class="flex items-center gap-2 text-[11.5px] font-semibold text-ink">
              <span class={[
                "size-1.5 shrink-0 rounded-full",
                if(@device.online?, do: "bg-ok-mark", else: "bg-crit-mark")
              ]}>
              </span>
              {@device.label}
            </p>
            <p class="as-num mt-1.5 text-[11px] text-ink-3">{@device.detail}</p>
          </div>

          <div :if={@current_user} class="flex items-center gap-2.5">
            <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-level-tint text-xs font-bold text-level">
              {initial(@current_user)}
            </span>
            <span class="min-w-0 grow">
              <span class="block truncate text-[12.5px] font-semibold text-ink">
                {@current_user.name}
              </span>
              <span class="block truncate text-[11px] text-ink-3">{@current_user.email}</span>
            </span>
            <.link
              href="/sign-out"
              method="delete"
              class="flex size-8 shrink-0 items-center justify-center rounded-lg text-ink-3 hover:bg-ghost hover:text-ink"
              title="Sair"
            >
              <span class="sr-only">Sair</span>
              <.icon name="hero-arrow-right-on-rectangle" class="size-4" />
            </.link>
          </div>

          <.theme_toggle />
        </div>
      </aside>

      <div class="flex min-w-0 grow flex-col">
        <header class="flex h-[62px] shrink-0 items-center gap-4 border-b border-hairline bg-surface px-6">
          <div class="min-w-0">
            <p :if={@crumb} class="text-[11px] text-ink-3">{@crumb}</p>
            <h1 :if={@title} class="text-[17px] font-bold tracking-tight">{@title}</h1>
            <p :if={@subtitle} class="text-[11px] text-ink-3">{@subtitle}</p>
          </div>
          <div :if={@actions != []} class="ml-auto flex items-center gap-2.5">
            {render_slot(@actions)}
          </div>
        </header>

        <main class="grow overflow-y-auto p-5">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Mostra o grupo de flash com títulos e conteúdo padrão.

  ## Exemplos

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "o mapa de mensagens de flash"
  attr :id, :string, default: "flash-group", doc: "o id opcional do contêiner"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Sem conexão")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Tentando reconectar")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Algo deu errado")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Tentando reconectar")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Alternador de tema claro/escuro/sistema.

  O `<head>` em `root.html.heex` aplica o tema antes da página pintar, para
  não haver um lampejo branco em quem usa o tema escuro.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      class="as-seg justify-between"
      role="group"
      aria-label="Tema da interface"
    >
      <button
        :for={
          option <- [
            %{theme: "system", icon: "hero-computer-desktop-micro", label: "Sistema"},
            %{theme: "light", icon: "hero-sun-micro", label: "Claro"},
            %{theme: "dark", icon: "hero-moon-micro", label: "Escuro"}
          ]
        }
        type="button"
        class="flex grow items-center justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme={option.theme}
        title={option.label}
      >
        <span class="sr-only">{option.label}</span>
        <.icon name={option.icon} class="size-4" />
      </button>
    </div>
    """
  end

  defp initial(%{name: name}) when is_binary(name) and name != "" do
    name |> String.first() |> String.upcase()
  end

  defp initial(_user), do: "?"
end
