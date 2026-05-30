defmodule SquadOps.Rules do
  @moduledoc """
  Business rules per squad: status workflow, work-item validations,
  Azure ↔ local field mapping, and sync policies.

  Rules are stored as JSONB maps to allow flexible per-squad configuration.
  """

  alias SquadOps.Repo
  alias SquadOps.Rules.SquadRule

  @default_workflow %{
    "transitions" => %{
      "new" => ["active", "removed"],
      "active" => ["resolved", "new", "removed"],
      "resolved" => ["closed", "active"],
      "closed" => ["active"],
      "removed" => []
    },
    "labels" => %{
      "new" => "Novo",
      "active" => "Em Andamento",
      "resolved" => "Resolvido",
      "closed" => "Fechado",
      "removed" => "Removido"
    }
  }

  @default_validations %{
    "story_requires_points" => true,
    "bug_requires_assignee" => false,
    "max_sprint_points" => 80,
    "block_invalid_transitions" => true
  }

  @default_field_mapping %{
    "type" => %{
      "Feature" => "feature",
      "User Story" => "story",
      "Task" => "task",
      "Bug" => "bug"
    },
    "status" => %{
      "New" => "new",
      "Active" => "active",
      "Resolved" => "resolved",
      "Closed" => "closed",
      "Removed" => "removed"
    }
  }

  @default_sync_policy %{
    "mode" => "manual",
    "auto" => true,
    "frequency_minutes" => 5,
    "scope" => "active_and_future",
    "conflict_resolution" => "azure_wins"
  }

  def defaults do
    %{
      workflow: @default_workflow,
      validations: @default_validations,
      field_mapping: @default_field_mapping,
      sync_policy: @default_sync_policy
    }
  end

  def get_or_init(squad_id) do
    case Repo.get_by(SquadRule, squad_id: squad_id) do
      nil ->
        attrs = Map.put(defaults(), :squad_id, squad_id)

        %SquadRule{}
        |> SquadRule.changeset(attrs)
        |> Repo.insert!()

      rule ->
        merge_defaults(rule)
    end
  end

  def update_section(%SquadRule{} = rule, section, value)
      when section in [:workflow, :validations, :field_mapping, :sync_policy] do
    rule
    |> SquadRule.changeset(%{section => value})
    |> Repo.update()
  end

  def change_rule(%SquadRule{} = rule, attrs \\ %{}), do: SquadRule.changeset(rule, attrs)

  def reset_section(%SquadRule{} = rule, section) do
    default = Map.fetch!(defaults(), section)
    update_section(rule, section, default)
  end

  defp merge_defaults(rule) do
    %{
      rule
      | workflow: Map.merge(@default_workflow, rule.workflow || %{}),
        validations: Map.merge(@default_validations, rule.validations || %{}),
        field_mapping: Map.merge(@default_field_mapping, rule.field_mapping || %{}),
        sync_policy: Map.merge(@default_sync_policy, rule.sync_policy || %{})
    }
  end
end
