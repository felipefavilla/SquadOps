defmodule SquadOps.RulesTest do
  use SquadOps.DataCase, async: true

  alias SquadOps.Rules
  alias SquadOps.Rules.SquadRule
  import SquadOps.Fixtures

  describe "get_or_init/1" do
    test "creates a rule with defaults when none exists" do
      squad = squad_fixture()
      rule = Rules.get_or_init(squad.id)

      assert %SquadRule{} = rule
      assert rule.squad_id == squad.id
      assert get_in(rule.workflow, ["labels", "new"]) == "Novo"
      assert rule.validations["story_requires_points"] == true
      assert rule.field_mapping["type"]["Feature"] == "feature"
      assert rule.sync_policy["scope"] == "active_and_future"
    end

    test "returns existing rule with defaults merged on top" do
      squad = squad_fixture()
      _first = Rules.get_or_init(squad.id)
      second = Rules.get_or_init(squad.id)
      assert second.squad_id == squad.id
    end
  end

  describe "update_section/3" do
    test "persists changes to a section" do
      squad = squad_fixture()
      rule = Rules.get_or_init(squad.id)

      new_validations = Map.put(rule.validations, "max_sprint_points", 120)

      assert {:ok, updated} = Rules.update_section(rule, :validations, new_validations)
      assert updated.validations["max_sprint_points"] == 120

      reloaded = Rules.get_or_init(squad.id)
      assert reloaded.validations["max_sprint_points"] == 120
    end

    test "raises on unknown sections" do
      squad = squad_fixture()
      rule = Rules.get_or_init(squad.id)

      assert_raise FunctionClauseError, fn ->
        Rules.update_section(rule, :not_a_section, %{})
      end
    end
  end

  describe "reset_section/2" do
    test "restores a section to defaults" do
      squad = squad_fixture()
      rule = Rules.get_or_init(squad.id)

      # mutate validations
      {:ok, mutated} =
        Rules.update_section(rule, :validations, %{"story_requires_points" => false})

      assert mutated.validations["story_requires_points"] == false

      {:ok, reset} = Rules.reset_section(mutated, :validations)
      assert reset.validations["story_requires_points"] == true
    end
  end

  test "defaults/0 has the expected sections" do
    defs = Rules.defaults()

    assert Map.keys(defs) |> Enum.sort() == [
             :field_mapping,
             :kpis,
             :sync_policy,
             :validations,
             :workflow
           ]
  end
end
