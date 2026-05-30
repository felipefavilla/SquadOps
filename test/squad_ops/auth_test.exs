defmodule SquadOps.AuthTest do
  use SquadOps.DataCase, async: true

  alias SquadOps.Auth
  alias SquadOps.Auth.Token
  import SquadOps.Fixtures

  describe "upsert_token/2" do
    test "creates a token when none exists" do
      squad = squad_fixture()

      assert {:ok, %Token{} = token} =
               Auth.upsert_token(squad.id, %{
                 pat_token: "abc",
                 azure_org_url: "https://dev.azure.com/foo"
               })

      assert token.squad_id == squad.id
      assert token.pat_token == "abc"
    end

    test "updates the token when one already exists" do
      squad = squad_fixture()
      _ = token_fixture(squad, %{pat_token: "old"})

      assert {:ok, %Token{pat_token: "new"}} =
               Auth.upsert_token(squad.id, %{
                 pat_token: "new",
                 azure_org_url: "https://dev.azure.com/foo"
               })

      # Still only a single token per squad
      assert %Token{pat_token: "new"} = Auth.get_token_for_squad(squad.id)
    end

    test "rejects invalid azure_org_url" do
      squad = squad_fixture()

      assert {:error, changeset} =
               Auth.upsert_token(squad.id, %{
                 pat_token: "abc",
                 azure_org_url: "http://example.com"
               })

      assert %{azure_org_url: _} = errors_on(changeset)
    end
  end

  describe "get_token_for_squad/1" do
    test "returns nil when no token exists" do
      squad = squad_fixture()
      assert is_nil(Auth.get_token_for_squad(squad.id))
    end

    test "returns the token when it exists" do
      squad = squad_fixture()
      _ = token_fixture(squad)
      assert %Token{} = Auth.get_token_for_squad(squad.id)
    end
  end

  describe "mark_validated/1" do
    test "writes a validated_at timestamp" do
      squad = squad_fixture()
      _ = token_fixture(squad)

      assert {:ok, %Token{validated_at: ts}} = Auth.mark_validated(squad.id)
      assert %NaiveDateTime{} = ts
    end

    test "returns :not_found error when there is no token" do
      squad = squad_fixture()
      assert {:error, :not_found} = Auth.mark_validated(squad.id)
    end
  end

  describe "delete_token/1" do
    test "deletes the token" do
      squad = squad_fixture()
      _ = token_fixture(squad)
      assert {:ok, _} = Auth.delete_token(squad.id)
      assert is_nil(Auth.get_token_for_squad(squad.id))
    end

    test "returns :not_found when no token" do
      squad = squad_fixture()
      assert {:error, :not_found} = Auth.delete_token(squad.id)
    end
  end
end
