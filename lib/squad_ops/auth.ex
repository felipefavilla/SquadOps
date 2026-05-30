defmodule SquadOps.Auth do
  alias SquadOps.Repo
  alias SquadOps.Auth.Token

  def get_token_for_squad(squad_id) do
    Repo.get_by(Token, squad_id: squad_id)
  end

  def upsert_token(squad_id, attrs) do
    case get_token_for_squad(squad_id) do
      nil ->
        %Token{}
        |> Token.changeset(Map.put(attrs, :squad_id, squad_id))
        |> Repo.insert()

      token ->
        token
        |> Token.changeset(attrs)
        |> Repo.update()
    end
  end

  def delete_token(squad_id) do
    case get_token_for_squad(squad_id) do
      nil -> {:error, :not_found}
      token -> Repo.delete(token)
    end
  end

  def mark_validated(squad_id) do
    case get_token_for_squad(squad_id) do
      nil ->
        {:error, :not_found}

      token ->
        token
        |> Token.changeset(%{
          validated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        })
        |> Repo.update()
    end
  end

  def change_token(%Token{} = token, attrs \\ %{}), do: Token.changeset(token, attrs)
end
