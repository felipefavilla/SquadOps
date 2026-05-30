defmodule SquadOps.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(admin user)

  schema "users" do
    field :email, :string
    field :name, :string
    field :hashed_password, :string
    field :role, :string, default: "user"
    field :password, :string, virtual: true

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password, :role])
    |> validate_required([:email, :name, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:password, min: 6, max: 72)
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:email)
    |> hash_password()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role])
    |> validate_required([:email, :name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:email)
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :hashed_password, Pbkdf2.hash_pwd_salt(password))
    end
  end
end
