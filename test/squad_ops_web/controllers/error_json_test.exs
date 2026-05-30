defmodule SquadOpsWeb.ErrorJSONTest do
  use SquadOpsWeb.ConnCase, async: true

  test "renders 404" do
    assert SquadOpsWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert SquadOpsWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
