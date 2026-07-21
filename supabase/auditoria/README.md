# supabase/auditoria

Consultas **somente leitura** (`SELECT`) usadas para diagnóstico pontual do banco.

- **Não são migrations.** Nada aqui altera schema ou dados. A fonte de verdade do
  schema continua sendo `supabase/migrations/` (ver CLAUDE.md §5).
- **Não são aplicadas automaticamente.** O workflow `run-sql-migration.yml` só
  dispara por push para `supabase-v3-fornecedor.sql`; arquivos desta pasta só
  rodam se alguém pedir explicitamente por `workflow_dispatch`.
- Ficam versionadas apenas como **registro histórico** da checagem feita.
