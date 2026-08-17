-- ============================================================================
-- DIAGNÓSTICO de conexões — só consulta, não altera nada.
--
-- Por que: as RPCs do dashboard levam ~2s medidas de fora, mas executam em
-- 48ms dentro do banco (comprovado pelo EXPLAIN da vw_paginas_diario). Sobra
-- ~1,8s de espera que NÃO é execução de query. Até uma consulta trivial
-- (1 linha de tabela pequena) leva de 216 a 754ms, oscilando muito.
--
-- Isso aponta para fila de conexão, não para query lenta — criar índice não
-- resolveria. Estas queries mostram quem está conectado e se há conexão presa.
--
-- Rode e me mande as 3 saídas.
-- ============================================================================

-- ── 1) Quem está conectado ──────────────────────────────────────────────────
-- O application_name identifica a origem: Power BI, n8n, PostgREST, psql...
select
  coalesce(nullif(application_name, ''), '(sem nome)') as aplicacao,
  usename as usuario,
  state,
  count(*) as conexoes,
  max(now() - state_change) as mais_antiga_nesse_estado
from pg_stat_activity
where datname = current_database()
group by 1, 2, 3
order by conexoes desc;

-- ── 2) Uso do limite de conexões ────────────────────────────────────────────
-- "presas" (idle in transaction) é o número que mais importa: conexão aberta,
-- sem trabalho, segurando vaga. Se for > 0 e persistente, achamos o culpado.
select
  count(*) as total,
  count(*) filter (where state = 'active') as ativas,
  count(*) filter (where state = 'idle') as ociosas,
  count(*) filter (where state = 'idle in transaction') as presas,
  (select setting::int from pg_settings where name = 'max_connections') as limite,
  round(100.0 * count(*) / (select setting::int from pg_settings where name = 'max_connections'), 1) as pct_do_limite
from pg_stat_activity
where datname = current_database();

-- ── 3) As consultas mais demoradas rodando agora ────────────────────────────
-- Se aparecer algo com muitos minutos, é uma query travada segurando recurso.
select
  pid,
  coalesce(nullif(application_name, ''), '(sem nome)') as aplicacao,
  state,
  now() - query_start as duracao,
  left(regexp_replace(query, '\s+', ' ', 'g'), 120) as consulta
from pg_stat_activity
where datname = current_database()
  and state <> 'idle'
  and query_start is not null
order by query_start
limit 15;
