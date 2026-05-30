defmodule SquadOpsWeb.PageController do
  use SquadOpsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
