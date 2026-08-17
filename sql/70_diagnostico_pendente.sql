-- ============================================================================
-- DIAGNÓSTICO — só consulta, não altera nada.
--
-- COMO RODAR: uma consulta por vez. O SQL Editor do Supabase mostra apenas o
-- resultado do último bloco quando você executa tudo junto — por isso
-- selecione o trecho de UMA consulta e clique em Run, depois a próxima.
--
-- São 3. Me mande as 3 saídas.
-- ============================================================================


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ CONSULTA 1 — a mais importante                                           │
-- │ Mostra quanto tempo a fn_trafego leva DENTRO do banco.                   │
-- │ Se der ~2000ms: a query é lenta e dá para otimizar.                      │
-- │ Se der ~100ms: o tempo está sendo perdido fora dela (rede/conexão).      │
-- └──────────────────────────────────────────────────────────────────────────┘

explain (analyze, buffers)
select * from mkt_wep.fn_trafego(current_date - 30, current_date);


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ CONSULTA 2                                                               │
-- │ Quem está conectado no banco. O application_name identifica a origem     │
-- │ (Power BI, n8n, PostgREST...).                                           │
-- └──────────────────────────────────────────────────────────────────────────┘

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


-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ CONSULTA 3                                                               │
-- │ Uso do limite de conexões. A coluna "presas" é a que importa:            │
-- │ conexão aberta sem trabalho, segurando vaga.                             │
-- └──────────────────────────────────────────────────────────────────────────┘

select
  count(*) as total,
  count(*) filter (where state = 'active') as ativas,
  count(*) filter (where state = 'idle') as ociosas,
  count(*) filter (where state = 'idle in transaction') as presas,
  (select setting::int from pg_settings where name = 'max_connections') as limite
from pg_stat_activity
where datname = current_database();
