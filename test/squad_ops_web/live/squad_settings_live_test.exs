defmodule SquadOpsWeb.SquadSettingsLiveTest do
  use SquadOpsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import SquadOps.Fixtures

  alias SquadOps.Auth

  setup %{conn: conn} do
    previous = System.get_env("AZURE_MODE")
    System.put_env("AZURE_MODE", "mock")

    on_exit(fn ->
      if previous,
        do: System.put_env("AZURE_MODE", previous),
        else: System.delete_env("AZURE_MODE")
    end)

    user = user_fixture()
    squad = squad_fixture(%{name: "Cfg Squad"})
    %{conn: log_in_user(conn, user), squad: squad}
  end

  test "renders the settings page", %{conn: conn, squad: squad} do
    {:ok, _view, html} = live(conn, ~p"/squads/#{squad.id}/settings")
    assert html =~ "Configurações"
    assert html =~ "Cfg Squad"
    assert html =~ "Credenciais Azure DevOps"
  end

  test "save event upserts the token", %{conn: conn, squad: squad} do
    {:ok, view, _html} = live(conn, ~p"/squads/#{squad.id}/settings")

    render_submit(view, "save", %{
      "settings" => %{
        "azure_org_url" => "https://dev.azure.com/my-org",
        "azure_project" => "MyProject",
        "pat_token" => "the-pat"
      }
    })

    token = Auth.get_token_for_squad(squad.id)
    assert token
    assert token.azure_org_url == "https://dev.azure.com/my-org"
  end

  test "test event with no token shows error flash", %{conn: conn, squad: squad} do
    {:ok, view, _html} = live(conn, ~p"/squads/#{squad.id}/settings")

    html = render_click(view, "test", %{})
    assert html =~ "Salve as configurações antes de testar"
  end
end
