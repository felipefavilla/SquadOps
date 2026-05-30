defmodule SquadOpsWeb.SquadRulesLiveTest do
  use SquadOpsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  alias SquadOps.Rules

  setup %{conn: conn} do
    user = user_fixture()
    squad = squad_fixture(%{name: "Rules Squad"})
    %{conn: log_in_user(conn, user), squad: squad}
  end

  test "renders the workflow tab by default", %{conn: conn, squad: squad} do
    {:ok, _view, html} = live(conn, ~p"/squads/#{squad.id}/rules")
    assert html =~ "Regras de Negócio"
    # workflow tab content
    assert html =~ "Transições permitidas"
    # tabs list
    assert html =~ "Workflow"
    assert html =~ "Validações"
    assert html =~ "Mapeamento"
    assert html =~ "Sincronização"
  end

  test "navigating to ?tab=validations renders validations tab", %{conn: conn, squad: squad} do
    {:ok, _view, html} = live(conn, ~p"/squads/#{squad.id}/rules?tab=validations")
    assert html =~ "Validações automáticas"
  end

  test "save_validations persists the new values", %{conn: conn, squad: squad} do
    {:ok, view, _html} = live(conn, ~p"/squads/#{squad.id}/rules?tab=validations")

    render_submit(view, "save_validations", %{
      "v" => %{
        "story_requires_points" => "false",
        "bug_requires_assignee" => "true",
        "block_invalid_transitions" => "true",
        "max_sprint_points" => "150"
      }
    })

    rule = Rules.get_or_init(squad.id)
    assert rule.validations["story_requires_points"] == false
    assert rule.validations["bug_requires_assignee"] == true
    assert rule.validations["max_sprint_points"] == 150
  end

  test "reset event restores default workflow", %{conn: conn, squad: squad} do
    {:ok, view, _html} = live(conn, ~p"/squads/#{squad.id}/rules")

    # toggle a transition off (new -> active is allowed by default)
    render_click(view, "toggle_transition", %{"from" => "new", "to" => "active"})

    rule = Rules.get_or_init(squad.id)
    refute "active" in (rule.workflow["transitions"]["new"] || [])

    # reset
    render_click(view, "reset", %{"section" => "workflow"})

    rule = Rules.get_or_init(squad.id)
    assert "active" in (rule.workflow["transitions"]["new"] || [])
  end
end
