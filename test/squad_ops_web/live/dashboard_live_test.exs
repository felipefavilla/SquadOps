defmodule SquadOpsWeb.DashboardLiveTest do
  use SquadOpsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  test "redirects to /login when unauthenticated", %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{})
    assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/")
  end

  test "renders squads when authenticated", %{conn: conn} do
    user = user_fixture()
    _squad_a = squad_fixture(%{name: "Alpha Squad"})
    _squad_b = squad_fixture(%{name: "Bravo Squad"})

    conn = log_in_user(conn, user)
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Dashboard"
    assert html =~ "Alpha Squad"
    assert html =~ "Bravo Squad"
  end
end
