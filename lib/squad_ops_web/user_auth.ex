defmodule SquadOpsWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias SquadOps.Accounts

  # Used by router pipeline
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Você precisa fazer login para acessar esta página.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> redirect(to: "/")
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: "/login")
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  # LiveView on_mount hooks
  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "Você precisa fazer login para acessar esta página."
        )
        |> Phoenix.LiveView.redirect(to: "/login")

      {:halt, socket}
    end
  end

  def on_mount(:fetch_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      user_id = session["user_id"]
      user_id && Accounts.get_user(user_id)
    end)
  end
end
