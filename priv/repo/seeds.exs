alias SquadOps.Repo
alias SquadOps.Squads.{Squad, Sprint, WorkItem}

# Squads
squads =
  Enum.map(
    [
      %{
        name: "Pagamentos",
        description: "Plataforma de pagamentos e cobranças",
        color: "#6366f1",
        azure_project: "Pagamentos"
      },
      %{
        name: "Identidade",
        description: "Autenticação, SSO e gestão de usuários",
        color: "#10b981",
        azure_project: "Identidade"
      },
      %{
        name: "Marketplace",
        description: "Catálogo de produtos e checkout",
        color: "#f59e0b",
        azure_project: "Marketplace"
      }
    ],
    fn attrs ->
      Repo.insert!(%Squad{} |> Squad.changeset(attrs) |> then(& &1))
      |> tap(fn s -> IO.puts("Squad criado: #{s.name}") end)
    end
  )

[pagamentos, identidade, marketplace] = squads

today = Date.utc_today()

# Sprints para cada squad
sprints =
  Enum.flat_map(squads, fn squad ->
    [
      Repo.insert!(%Sprint{
        squad_id: squad.id,
        name: "Sprint 12",
        start_date: Date.add(today, -14),
        end_date: Date.add(today, 0),
        status: "active"
      }),
      Repo.insert!(%Sprint{
        squad_id: squad.id,
        name: "Sprint 13",
        start_date: Date.add(today, 1),
        end_date: Date.add(today, 14),
        status: "future"
      }),
      Repo.insert!(%Sprint{
        squad_id: squad.id,
        name: "Sprint 11",
        start_date: Date.add(today, -28),
        end_date: Date.add(today, -15),
        status: "past"
      })
    ]
  end)

IO.puts("#{length(sprints)} sprints criados")

find_sprint = fn squad_id, status ->
  Enum.find(sprints, fn s -> s.squad_id == squad_id and s.status == status end)
end

# Work Items — Pagamentos
pagamentos_active = find_sprint.(pagamentos.id, "active")
pagamentos_future = find_sprint.(pagamentos.id, "future")

Enum.each(
  [
    %{
      title: "Integrar gateway Stripe v3",
      type: "feature",
      status: "active",
      story_points: 8,
      assigned_to: "Ana Lima",
      sprint_id: pagamentos_active.id
    },
    %{
      title: "Corrigir timeout em pagamentos PIX",
      type: "bug",
      status: "active",
      story_points: 3,
      assigned_to: "Carlos Melo",
      sprint_id: pagamentos_active.id
    },
    %{
      title: "Criar endpoint de estorno parcial",
      type: "story",
      status: "new",
      story_points: 5,
      sprint_id: pagamentos_active.id
    },
    %{
      title: "Adicionar relatório de reconciliação",
      type: "story",
      status: "resolved",
      story_points: 5,
      assigned_to: "Ana Lima",
      sprint_id: pagamentos_active.id
    },
    %{
      title: "Refatorar módulo de antifraude",
      type: "task",
      status: "new",
      story_points: 3,
      sprint_id: pagamentos_future.id
    },
    %{
      title: "Suporte a cartão de débito",
      type: "feature",
      status: "new",
      story_points: 13,
      sprint_id: pagamentos_future.id
    },
    %{
      title: "Testes de carga no gateway",
      type: "task",
      status: "new",
      story_points: 2,
      assigned_to: "Carlos Melo",
      sprint_id: pagamentos_future.id
    }
  ],
  fn attrs ->
    Repo.insert!(%WorkItem{squad_id: pagamentos.id} |> WorkItem.changeset(attrs) |> then(& &1))
  end
)

# Work Items — Identidade
identidade_active = find_sprint.(identidade.id, "active")
identidade_future = find_sprint.(identidade.id, "future")

Enum.each(
  [
    %{
      title: "Implementar login com Google",
      type: "feature",
      status: "active",
      story_points: 8,
      assigned_to: "Beatriz Costa",
      sprint_id: identidade_active.id
    },
    %{
      title: "Migrar tokens JWT para RS256",
      type: "task",
      status: "active",
      story_points: 5,
      assigned_to: "Diego Neves",
      sprint_id: identidade_active.id
    },
    %{
      title: "Adicionar MFA por TOTP",
      type: "story",
      status: "new",
      story_points: 8,
      sprint_id: identidade_active.id
    },
    %{
      title: "Corrigir sessão duplicada no mobile",
      type: "bug",
      status: "resolved",
      story_points: 2,
      assigned_to: "Beatriz Costa",
      sprint_id: identidade_active.id
    },
    %{
      title: "SSO com SAML 2.0",
      type: "feature",
      status: "new",
      story_points: 13,
      sprint_id: identidade_future.id
    },
    %{
      title: "Auditoria de logins suspeitos",
      type: "story",
      status: "new",
      story_points: 5,
      sprint_id: identidade_future.id
    }
  ],
  fn attrs ->
    Repo.insert!(%WorkItem{squad_id: identidade.id} |> WorkItem.changeset(attrs) |> then(& &1))
  end
)

# Work Items — Marketplace
marketplace_active = find_sprint.(marketplace.id, "active")
marketplace_future = find_sprint.(marketplace.id, "future")

Enum.each(
  [
    %{
      title: "Recomendação de produtos com ML",
      type: "feature",
      status: "new",
      story_points: 13,
      sprint_id: marketplace_active.id
    },
    %{
      title: "Corrigir preço exibido com desconto",
      type: "bug",
      status: "active",
      story_points: 2,
      assigned_to: "Fernanda Rocha",
      sprint_id: marketplace_active.id
    },
    %{
      title: "Filtro de busca por avaliação",
      type: "story",
      status: "active",
      story_points: 3,
      assigned_to: "Gustavo Pires",
      sprint_id: marketplace_active.id
    },
    %{
      title: "Exportar catálogo em CSV",
      type: "story",
      status: "resolved",
      story_points: 2,
      assigned_to: "Fernanda Rocha",
      sprint_id: marketplace_active.id
    },
    %{
      title: "Checkout em 1 clique",
      type: "feature",
      status: "new",
      story_points: 8,
      sprint_id: marketplace_future.id
    },
    %{
      title: "Integrar sistema de avaliações",
      type: "story",
      status: "new",
      story_points: 5,
      sprint_id: marketplace_future.id
    },
    %{
      title: "Cache de catálogo com Redis",
      type: "task",
      status: "new",
      story_points: 3,
      sprint_id: marketplace_future.id
    }
  ],
  fn attrs ->
    Repo.insert!(%WorkItem{squad_id: marketplace.id} |> WorkItem.changeset(attrs) |> then(& &1))
  end
)

IO.puts("Seeds concluídos com sucesso!")

# --- Usuário Admin ---
alias SquadOps.Accounts

case Accounts.get_user_by_email("admin@squadops.local") do
  nil ->
    Accounts.create_user!(%{
      email: "admin@squadops.local",
      name: "Administrador",
      password: "Admin@123",
      role: "admin"
    })

    IO.puts("Admin criado: admin@squadops.local / Admin@123")

  _ ->
    IO.puts("Admin já existe.")
end
