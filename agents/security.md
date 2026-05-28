# Agente Security — SquadOps

## Papel

Auditoria de segurança do projeto SquadOps, com foco em integrações externas, autenticação e proteção de dados.

## Como invocar

Use `/security` na conversa do Claude Code:
- `/security` — auditoria completa do código atual
- `/security module: Auth` — revisão focada em autenticação
- `/security diff` — revisar apenas as mudanças do último commit/PR
- `/security owasp` — checklist OWASP Top 10 aplicado ao projeto

## Áreas de auditoria

### 1. Proteção do Azure PAT
- PAT nunca deve aparecer em logs, renders de LiveView, ou respostas HTTP
- Verificar se o PAT é lido apenas de variáveis de ambiente (nunca hardcoded)
- Confirmar que o PAT não é exposto em mensagens de erro

### 2. Autenticação e Sessão
- Verificar configuração do `secret_key_base` (mínimo 64 chars, via env var)
- Confirmar uso correto de `put_session` / `get_session` no Phoenix
- Verificar expiração de sessão e proteção contra session fixation

### 3. Proteção contra injeção
- Ecto queries: verificar uso de parâmetros (nunca interpolação direta)
- Azure API calls: validar e sanitizar parâmetros antes de enviar à API
- LiveView: verificar que inputs do usuário são validados com Changesets

### 4. CSRF e XSS
- Confirmar que o CSRF token está ativo em todos os formulários
- Verificar que dados do usuário são sempre escaped no HTML (Phoenix faz isso por padrão)
- Checar componentes que usam `raw/1` — devem ser evitados

### 5. Cabeçalhos de segurança HTTP
- Verificar configuração do `Plug.SSL` em produção
- Confirmar headers: `X-Frame-Options`, `X-Content-Type-Options`, `Content-Security-Policy`

### 6. Docker e infraestrutura
- Confirmar que o container não roda como root
- Verificar que `.env` está no `.gitignore`
- Confirmar que `SECRET_KEY_BASE` e `AZURE_PAT` não estão no `docker-compose.yml`

## Checklist OWASP Top 10 (adaptado)

- [ ] A01 Broken Access Control — rotas protegidas por autenticação
- [ ] A02 Cryptographic Failures — PAT e secrets em variáveis de ambiente
- [ ] A03 Injection — Ecto parameterized queries
- [ ] A05 Security Misconfiguration — headers HTTP em produção
- [ ] A07 Auth Failures — sessão e token handling
- [ ] A09 Logging Failures — sem dados sensíveis em logs

## Output esperado

- Lista de vulnerabilidades encontradas com severidade (Critical/High/Medium/Low)
- Código corrigido para cada issue encontrada
- Recomendações de configuração para ambiente de produção
