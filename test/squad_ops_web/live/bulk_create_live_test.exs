defmodule SquadOpsWeb.BulkCreateLiveTest do
  use SquadOpsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  alias SquadOps.Squads

  setup %{conn: conn} do
    user = user_fixture()
    squad = squad_fixture(%{name: "Bulk Squad"})
    %{conn: log_in_user(conn, user), squad: squad}
  end

  test "renders the bulk-create page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/bulk-create")
    assert html =~ "Criar Work Items em Massa"
    assert html =~ "Bulk Squad"
  end

  test "preview event populates list of titles", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/bulk-create")

    html =
      render_change(view, "preview", %{
        "titles" => "Item 1\nItem 2\nItem 3",
        "type" => "task",
        "sprint_id" => ""
      })

    assert html =~ "Item 1"
    assert html =~ "Item 2"
    assert html =~ "Item 3"
    assert html =~ "3 iten"
  end

  test "create event persists work items", %{conn: conn, squad: squad} do
    {:ok, view, _html} = live(conn, ~p"/bulk-create")

    # populate preview first
    render_change(view, "preview", %{
      "titles" => "Item A\nItem B",
      "type" => "task",
      "sprint_id" => ""
    })

    render_click(view, "create", %{})

    items = Squads.list_work_items(squad.id)
    titles = Enum.map(items, & &1.title)
    assert "Item A" in titles
    assert "Item B" in titles
  end
end
