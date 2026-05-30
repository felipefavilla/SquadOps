defmodule SquadOpsWeb.Layouts do
  use SquadOpsWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, default: %{}
  attr :current_scope, :map, default: nil
  attr :current_user, :map, default: nil
  attr :current_path, :string, default: "/"
  attr :inner_content, :any, default: nil

  def app(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open min-h-screen">
      <input id="sidebar-drawer" type="checkbox" class="drawer-toggle" />

      <%!-- Conteúdo principal --%>
      <div class="drawer-content flex flex-col">
        <%!-- Topbar mobile --%>
        <div class="navbar bg-base-100 border-b border-base-200 lg:hidden px-4">
          <div class="flex-none">
            <label for="sidebar-drawer" class="btn btn-ghost btn-sm">
              <.icon name="hero-bars-3" class="size-5" />
            </label>
          </div>
          <div class="flex-1 font-bold text-base ml-2">
            <span class="text-primary">⚡</span> SquadOps
          </div>
          <div class="flex-none">
            <.theme_toggle />
          </div>
        </div>

        <%!-- Área de conteúdo --%>
        <main class="flex-1 p-4 sm:p-6 bg-base-200 min-h-screen">
          {@inner_content}
        </main>
      </div>

      <%!-- Sidebar --%>
      <div class="drawer-side z-40">
        <label for="sidebar-drawer" aria-label="Fechar menu" class="drawer-overlay"></label>

        <aside class="bg-base-100 border-r border-base-200 w-64 min-h-full flex flex-col">
          <%!-- Logo --%>
          <div class="p-4 border-b border-base-200">
            <a href={~p"/"} class="flex items-center gap-3">
              <div class="bg-primary text-primary-content rounded-lg p-2">
                <.icon name="hero-bolt" class="size-5" />
              </div>
              <div>
                <div class="font-bold text-base leading-tight">SquadOps</div>
                <div class="text-xs text-base-content/50">Dev Squad Manager</div>
              </div>
            </a>
          </div>

          <%!-- Menu principal --%>
          <nav class="flex-1 p-3 space-y-1">
            <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider px-3 py-2">
              Menu
            </p>

            <.nav_item
              href={~p"/"}
              icon="hero-home"
              label="Dashboard"
              active={@current_path == "/"}
            />
            <.nav_item
              href={~p"/backlog"}
              icon="hero-clipboard-document-list"
              label="Backlog"
              active={@current_path == "/backlog"}
            />
            <.nav_item
              href={~p"/bulk-create"}
              icon="hero-plus-circle"
              label="Criar em Massa"
              active={@current_path == "/bulk-create"}
            />
            <.nav_item
              href={~p"/connect"}
              icon="hero-link"
              label="Conectar Azure"
              active={@current_path == "/connect"}
            />
            <.nav_item
              href={~p"/logs"}
              icon="hero-document-text"
              label="Logs de Sync"
              active={@current_path == "/logs"}
            />

            <div class="divider my-2 text-xs text-base-content/30">Squads</div>

            <.nav_item
              href={~p"/"}
              icon="hero-user-group"
              label="Todos os Squads"
              active={false}
            />

            <%!-- Menu contextual quando dentro de um squad --%>
            <%= if squad_id = extract_squad_id(@current_path) do %>
              <div class="mt-2 ml-2 pl-2 border-l border-base-200 space-y-1">
                <p class="text-xs text-base-content/40 px-3 py-1">Squad ativo</p>
                <.nav_item
                  href={~p"/squads/#{squad_id}"}
                  icon="hero-view-columns"
                  label="Kanban"
                  active={@current_path == "/squads/#{squad_id}"}
                />
                <.nav_item
                  href={~p"/squads/#{squad_id}/settings"}
                  icon="hero-cog-6-tooth"
                  label="Configurações"
                  active={@current_path == "/squads/#{squad_id}/settings"}
                />
                <.nav_item
                  href={~p"/squads/#{squad_id}/rules"}
                  icon="hero-shield-check"
                  label="Regras de Negócio"
                  active={@current_path == "/squads/#{squad_id}/rules"}
                />
              </div>
            <% end %>
          </nav>

          <%!-- Rodapé do sidebar --%>
          <div class="p-3 border-t border-base-200 space-y-1">
            <div class="flex items-center justify-between px-3 py-2 rounded-lg">
              <span class="text-xs text-base-content/50">Tema</span>
              <.theme_toggle />
            </div>

            <div :if={@current_user} class="flex items-center gap-3 px-3 py-2 rounded-lg">
              <div class="avatar placeholder">
                <div class="bg-neutral text-neutral-content rounded-full w-8">
                  <span class="text-xs">
                    {String.first(@current_user.name || "?")}
                  </span>
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium truncate">{@current_user.name}</div>
                <div class="text-xs text-base-content/50 truncate">{@current_user.email}</div>
              </div>
            </div>

            <.form :let={_} for={%{}} action={~p"/users/session"} method="delete">
              <button
                type="submit"
                class="btn btn-ghost btn-sm w-full justify-start gap-2 text-error hover:bg-error/10"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Sair
              </button>
            </.form>
          </div>
        </aside>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  defp extract_squad_id(path) when is_binary(path) do
    case Regex.run(~r{^/squads/(\d+)}, path) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp extract_squad_id(_), do: nil

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp nav_item(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
        if(@active,
          do: "bg-primary text-primary-content",
          else: "text-base-content/70 hover:bg-base-200 hover:text-base-content"
        )
      ]}
    >
      <.icon name={@icon} class="size-5 shrink-0" />
      {@label}
    </a>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
