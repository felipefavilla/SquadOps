defmodule SquadOpsWeb.SquadLiveTest do
  use SquadOpsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  alias SquadOps.Squads

  setup %{conn: conn} do
    user = user_fixture()
    squad = squad_fixture(%{name: "Kanban Squad"})
    sprint = sprint_fixture(squad, %{status: "active", name: "Sprint Atual"})
    _item = work_item_fixture(squad, %{title: "Tarefa A", status: "new", sprint_id: sprint.id})

    %{conn: log_in_user(conn, user), squad: squad, sprint: sprint}
  end

  test "renders the kanban with default columns", %{conn: conn, squad: squad} do
    {:ok, _view, html} = live(conn, ~p"/squads/#{squad.id}")
    assert html =~ "Kanban Squad"
    # default columns labels (since no rules.workflow.columns)
    assert html =~ "Novo"
    assert html =~ "Em Andamento"
    assert html =~ "Resolvido"
  end

  test "handle_event 'move' updates the item status", %{conn: conn, squad: squad} do
    {:ok, view, _html} = live(conn, ~p"/squads/#{squad.id}")

    item = Squads.list_work_items(squad.id) |> hd()
    assert item.status == "new"

    render_click(view, "move", %{"item-id" => to_string(item.id), "status" => "active"})

    reloaded = Squads.get_work_item!(item.id)
    assert reloaded.status == "active"
  end
end
