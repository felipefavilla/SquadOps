defmodule SquadOpsWeb.LoginLiveTest do
  use SquadOpsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders login form", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/login")
    assert html =~ "SquadOps"
    assert html =~ "Faça login"
    assert html =~ "email"
    assert html =~ "password"
  end
end
