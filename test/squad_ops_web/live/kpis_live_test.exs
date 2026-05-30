defmodule SquadOpsWeb.KpisLiveTest do
  use SquadOpsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  alias SquadOps.Kpis

  setup %{conn: conn} do
    user = user_fixture()
    squad = squad_fixture(%{name: "KPI Squad"})
    sprint = sprint_fixture(squad, %{status: "active", name: "Sprint Z"})

    _ =
      work_item_fixture(squad, %{
        type: "story",
        status: "resolved",
        story_points: 3.0,
        sprint_id: sprint.id
      })

    %{conn: log_in_user(conn, user), squad: squad, sprint: sprint}
  end

  test "renders KPI page with charts and per-sprint table", %{conn: conn, squad: squad} do
    {:ok, _view, html} = live(conn, ~p"/kpis")

    assert html =~ "KPIs"
    assert html =~ "Eficiência por Sprint"
    assert html =~ "Sprint Z"
    # gráfico via hook
    assert html =~ ~s(phx-hook="Chart")
    # a página seleciona o primeiro squad por padrão
    assert html =~ squad.name
  end

  test "shows burndown after snapshots exist", %{conn: conn, squad: squad} do
    {:ok, _} = Kpis.capture_snapshots(squad.id)

    {:ok, _view, html} = live(conn, ~p"/kpis")
    assert html =~ "chart-burndown"
  end
end
