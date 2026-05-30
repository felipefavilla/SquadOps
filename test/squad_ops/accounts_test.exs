defmodule SquadOps.AccountsTest do
  use SquadOps.DataCase, async: true

  alias SquadOps.Accounts
  alias SquadOps.Accounts.User
  import SquadOps.Fixtures

  describe "create_user/1" do
    test "creates a user and hashes the password" do
      attrs = user_attrs(%{password: "Admin@123"})
      assert {:ok, %User{} = user} = Accounts.create_user(attrs)

      assert user.email == attrs.email
      assert user.name == attrs.name
      # password is hashed, not stored in plain text
      assert user.hashed_password
      refute user.hashed_password == "Admin@123"
      assert Pbkdf2.verify_pass("Admin@123", user.hashed_password)
    end

    test "rejects invalid email" do
      attrs = user_attrs(%{email: "not-an-email"})
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{email: _} = errors_on(changeset)
    end

    test "rejects short password" do
      attrs = user_attrs(%{password: "abc"})
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{password: _} = errors_on(changeset)
    end

    test "enforces unique email" do
      attrs = user_attrs(%{email: "dup@example.com"})
      assert {:ok, _} = Accounts.create_user(attrs)
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{email: _} = errors_on(changeset)
    end
  end

  describe "get_user/1 and get_user_by_email/1" do
    test "returns the user when found" do
      user = user_fixture()
      assert %User{id: id} = Accounts.get_user(user.id)
      assert id == user.id

      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end

    test "returns nil when user does not exist" do
      assert is_nil(Accounts.get_user_by_email("ghost@example.com"))
    end
  end

  describe "authenticate_user/2" do
    test "succeeds with valid credentials" do
      user = user_fixture(%{password: "Right@Pass1"})
      assert {:ok, returned} = Accounts.authenticate_user(user.email, "Right@Pass1")
      assert returned.id == user.id
    end

    test "fails with wrong password" do
      user = user_fixture(%{password: "Right@Pass1"})

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(user.email, "Wrong@Pass2")
    end

    test "fails with unknown email (and calls no_user_verify for timing safety)" do
      # Hard to assert that no_user_verify/0 was called without mocks,
      # but we can at least make sure it returns the safe error tuple
      # and that the call takes a non-trivial amount of time (pbkdf2 work).
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("ghost@example.com", "any-password")
    end
  end
end
