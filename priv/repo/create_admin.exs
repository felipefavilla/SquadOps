alias SquadOps.Accounts
alias SquadOps.Repo

email = "admin@squadops.local"

case Accounts.get_user_by_email(email) do
  nil ->
    :ok

  existing ->
    # Remove para regerar o hash (útil quando a lib de hash muda)
    Repo.delete!(existing)
end

case Accounts.create_user(%{
       email: email,
       name: "Administrador",
       password: "Admin@123",
       role: "admin"
     }) do
  {:ok, u} -> IO.puts("Admin criado: #{u.email}")
  {:error, cs} -> IO.inspect(cs.errors, label: "Erros")
end
