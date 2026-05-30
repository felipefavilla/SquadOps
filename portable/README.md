# SquadOps Portátil

Pacote autocontido que roda em qualquer Windows 10/11 x64 **sem instalação**.

## Estrutura

```
portable/
├── app/                  ← release Phoenix (gerado por scripts\build_release.ps1)
├── pgsql/                ← PostgreSQL portátil (você baixa)
├── pgdata/               ← dados do banco (criado na primeira execução)
├── bin/
│   ├── setup.bat         ← primeira execução (init DB + migrate + admin)
│   ├── start.bat         ← inicia Postgres + servidor
│   ├── stop.bat          ← para o Postgres
│   ├── migrate.bat       ← roda migrations
│   └── reset_admin.bat   ← recria admin com senha do .env
├── .env                  ← configurações (criado pelo build_release.ps1)
└── README.md
```

## Como montar (no PC de desenvolvimento, com Elixir instalado)

1. Rode `.\scripts\build_release.ps1` na raiz do projeto.
   Isso preenche `portable\app\` e gera `portable\.env` com SECRET_KEY_BASE.

2. Baixe o ZIP do PostgreSQL 16 Windows x86-64 binaries em
   <https://www.enterprisedb.com/download-postgresql-binaries>.
   Descompacte o conteúdo da pasta `pgsql\` do ZIP **dentro de** `portable\pgsql\`.
   Após descompactar você deve ter `portable\pgsql\bin\initdb.exe`.

3. Copie a pasta `portable\` inteira para o pendrive.

## Como usar (no notebook do trabalho)

1. Copie a pasta `portable\` para qualquer lugar (Desktop, Documentos…).

2. **Primeira execução**: clique duas vezes em `bin\setup.bat`.
   Inicializa o cluster Postgres, cria o banco, roda migrations e cria o admin.

3. **Iniciar o servidor**: clique duas vezes em `bin\start.bat`.
   Abra <http://localhost:4000> no navegador.
   - Login: o valor de `ADMIN_EMAIL` no `.env` (default `admin@squadops.local`)
   - Senha: o valor de `ADMIN_PASSWORD` no `.env` (default `Admin@123`)

4. **Conectar ao Azure DevOps**: dentro da app, vá em **Squad → Configurações** e cole:
   - Organization URL (ex: `https://dev.azure.com/sua-org`)
   - Project name
   - PAT (Personal Access Token)

   Depois clique em **Testar conexão** e **Sincronizar agora**.

5. **Parar**: feche a janela do `start.bat` (ou Ctrl+C) e rode `bin\stop.bat`.

## Modo Mock vs Real

Edite `.env`:
- `AZURE_MODE=mock` — usa dados fake, não chama Azure
- `AZURE_MODE=real` — chama a API real do Azure DevOps usando o PAT configurado

Para alterar, edite o `.env`, pare e reinicie o servidor.

## Trocar a senha do admin

1. Edite `ADMIN_PASSWORD` em `.env`.
2. Pare o servidor.
3. Rode `bin\reset_admin.bat`.
4. Reinicie com `bin\start.bat`.

## Atualizar a aplicação

No PC de desenvolvimento, após mudanças no código:
1. Rode `.\scripts\build_release.ps1` de novo (sobrescreve `portable\app\`).
2. Copie só a pasta `portable\app\` para o notebook (preserva `.env`, `pgdata\` e `pgsql\`).
3. Se houver migrations novas, rode `bin\migrate.bat` no notebook.

## Solução de problemas

- **`pg_ctl: another server might be running`** → outra instância do Postgres usa a porta. Mude `port = 5433` em `pgdata\postgresql.conf` (ou mate o processo).
- **`port 4000 already in use`** → mude `PORT=4001` no `.env`.
- **Erro de SECRET_KEY_BASE** → o `.env` não foi gerado. Rode `scripts\build_release.ps1` de novo no PC de dev.
- **`initdb` falha com erro de locale** → certifique-se de que o ZIP do Postgres é Windows x86-64 e descompactado completo (deve ter pasta `share\`).
