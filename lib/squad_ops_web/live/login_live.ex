defmodule SquadOpsWeb.LoginLive do
  use SquadOpsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Flash de erro pode vir de redirect do controller
    {:ok, assign(socket, page_title: "Login"), layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center p-4">
      <div class="card w-full max-w-sm bg-base-100 shadow-xl">
        <div class="card-body gap-6">
          <div class="text-center">
            <div class="text-4xl mb-2">⚡</div>
            <h1 class="text-2xl font-bold">SquadOps</h1>
            <p class="text-base-content/50 text-sm mt-1">Faça login para continuar</p>
          </div>

          <div :if={@flash["error"]} role="alert" class="alert alert-error py-2">
            <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
            <span class="text-sm">{@flash["error"]}</span>
          </div>

          <form action={~p"/users/session"} method="post" class="flex flex-col gap-4">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div class="form-control gap-1">
              <label class="label py-0">
                <span class="label-text text-sm font-medium">Email</span>
              </label>
              <label class="input input-bordered flex items-center gap-2">
                <.icon name="hero-envelope" class="size-4 opacity-50 shrink-0" />
                <input
                  type="email"
                  name="email"
                  placeholder="admin@squadops.local"
                  required
                  autofocus
                  class="grow"
                />
              </label>
            </div>

            <div class="form-control gap-1">
              <label class="label py-0">
                <span class="label-text text-sm font-medium">Senha</span>
              </label>
              <label class="input input-bordered flex items-center gap-2">
                <.icon name="hero-lock-closed" class="size-4 opacity-50 shrink-0" />
                <input
                  type="password"
                  name="password"
                  placeholder="••••••••"
                  required
                  class="grow"
                />
              </label>
            </div>

            <button type="submit" class="btn btn-primary w-full mt-2">
              <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Entrar
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
