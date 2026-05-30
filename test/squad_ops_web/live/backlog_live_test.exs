defmodule SquadOpsWeb.BacklogLiveTest do
  use SquadOpsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  setup %{conn: conn} do
    user = user_fixture()
    squad = squad_fixture(%{name: "Backlog Squad"})
    _ = work_item_fixture(squad, %{title: "Story X", type: "story"})
    _ = work_item_fixture(squad, %{title: "Bug Y", type: "bug"})
    %{conn: log_in_user(conn, user), squad: squad}
  end

  test "renders backlog table with items", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/backlog")
    assert html =~ "Backlog"
    assert html =~ "Story X"
    assert html =~ "Bug Y"
  end

  test "filter event narrows results", %{conn: conn, squad: squad} do
    {:ok, view, _html} = live(conn, ~p"/backlog")

    html =
      render_change(view, "filter", %{
        "squad_id" => to_string(squad.id),
        "type" => "bug",
        "status" => ""
      })

    assert html =~ "Bug Y"
    refute html =~ "Story X"
  end
end
