defmodule SquadOps.KpisTest do
  use SquadOps.DataCase, async: true

  alias SquadOps.Kpis
  import SquadOps.Fixtures

  setup do
    squad = squad_fixture()
    sprint = sprint_fixture(squad, %{status: "active", name: "Sprint KPI"})

    # 2 User Stories: uma resolvida (4 pts), uma nova (2 pts)
    _ =
      work_item_fixture(squad, %{
        type: "story",
        status: "resolved",
        story_points: 4.0,
        sprint_id: sprint.id
      })

    _ =
      work_item_fixture(squad, %{
        type: "story",
        status: "new",
        story_points: 2.0,
        sprint_id: sprint.id
      })

    %{squad: squad, sprint: sprint}
  end

  test "sprint_metrics computes points stats and efficiency", %{squad: squad, sprint: sprint} do
    [m] = Kpis.sprint_metrics(squad.id) |> Enum.filter(&(&1.sprint.id == sprint.id))

    assert m.items == 2
    assert m.points == 6.0
    assert m.mean == 3.0
    assert m.median == 3.0
    assert_in_delta m.stddev, 1.0, 0.001
    assert m.planned_us == 2
    assert m.completed_us == 1
    assert_in_delta m.efficiency, 0.5, 0.001
  end

  test "capture_snapshots writes a daily snapshot and burndown reads it",
       %{squad: squad, sprint: sprint} do
    assert {:ok, 1} = Kpis.capture_snapshots(squad.id)
    # idempotente no mesmo dia (upsert por sprint_id + data)
    assert {:ok, 1} = Kpis.capture_snapshots(squad.id)

    b = Kpis.burndown(sprint.id)
    assert b.has_data
    assert List.last(b.remaining) == 2.0
  end

  test "stats helpers" do
    assert Kpis.mean([2, 4]) == 3.0
    assert Kpis.median([1, 3, 5]) == 3
    assert Kpis.median([1, 2, 3, 4]) == 2.5
    assert Kpis.stddev([5]) == 0.0
  end
end
