defmodule SquadOpsWeb.SquadLiveTest do
  use SquadOpsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  setup %{conn: conn} do
    user = user_fixture()
    squad = squad_fixture(%{name: "Kanban Squad"})
    sprint = sprint_fixture(squad, %{status: "active", name: "Sprint Atual"})
    _item = work_item_fixture(squad, %{title: "Tarefa A", status: "new", sprint_id: sprint.id})

    %{conn: log_in_user(conn, user), squad: squad, sprint: sprint}
  end

  test "renders the management dashboard with queue, area and iteration sections",
       %{conn: conn, squad: squad} do
    {:ok, _view, html} = live(conn, ~p"/squads/#{squad.id}")
    assert html =~ "Kanban Squad"
    assert html =~ "Filas do Kanban"
    assert html =~ "Itens por Área"
    assert html =~ "Itens por Iteration"
    # nome da iteration ativa aparece na tabela por iteration
    assert html =~ "Sprint Atual"
    # colunas padrão (sem rules.workflow.columns sincronizadas)
    assert html =~ "Novo"
  end

  test "filtering by iteration keeps the page rendering", %{
    conn: conn,
    squad: squad,
    sprint: sprint
  } do
    {:ok, view, _html} = live(conn, ~p"/squads/#{squad.id}")

    html =
      view
      |> form("form[phx-change=filter]", %{"area" => "", "iteration_id" => to_string(sprint.id)})
      |> render_change()

    assert html =~ "Filas do Kanban"
  end
end
