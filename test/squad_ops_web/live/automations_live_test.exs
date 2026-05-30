defmodule SquadOpsWeb.AutomationsLiveTest do
  use SquadOpsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  setup %{conn: conn} do
    previous = System.get_env("AZURE_MODE")
    System.put_env("AZURE_MODE", "mock")

    on_exit(fn ->
      if previous,
        do: System.put_env("AZURE_MODE", previous),
        else: System.delete_env("AZURE_MODE")
    end)

    user = user_fixture()
    squad = squad_fixture(%{name: "Auto Squad", azure_project: "MockProject"})
    _ = token_fixture(squad)

    %{conn: log_in_user(conn, user), squad: squad}
  end

  test "renders automations page", %{conn: conn, squad: squad} do
    {:ok, _view, html} = live(conn, ~p"/automations")
    assert html =~ "Automações"
    assert html =~ squad.name
    assert html =~ "Criar no Azure"
  end

  test "bulk-create path still routes here", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/bulk-create")
    assert html =~ "Automações"
  end

  test "creates items via Azure (mock) and reports them", %{conn: conn, squad: squad} do
    {:ok, view, _html} = live(conn, ~p"/automations")

    view
    |> form("form[phx-change=change]", %{
      "squad_id" => to_string(squad.id),
      "type" => "story",
      "area_path" => "",
      "iteration_path" => "",
      "parent_id" => "",
      "titles" => "Auto A\nAuto B"
    })
    |> render_change()

    view |> element("button[phx-click=create]") |> render_click()

    html = render(view)
    assert html =~ "criado(s) no Azure"
    assert html =~ "Auto A"
    assert html =~ "Auto B"
  end
end
