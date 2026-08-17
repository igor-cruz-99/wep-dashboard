-- ============================================================================
-- DIAGNÓSTICO de performance — só consulta, não altera nada.
--
-- Contexto: as RPCs que alimentam o dashboard levam ~2s cada
-- (fn_serie_diaria 2238ms, fn_funil 2224ms, fn_trafego 2171ms, fn_paginas
-- 1764ms, fn_kpis 1331ms), enquanto as que não tocam nas views pesadas levam
-- ~170ms. As lentas têm em comum a leitura de core.ads_metrics e
-- core.paginas_ga4 via views.
--
-- Rode e me mande as 4 saídas.
-- ============================================================================

-- ── 1) Tamanho das tabelas base ────────────────────────────────────────────
select
  n.nspname || '.' || c.relname as tabela,
  to_char(c.reltuples::bigint, 'FM999G999G999') as linhas_aprox,
  pg_size_pretty(pg_total_relation_size(c.oid)) as tamanho
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and (
    (n.nspname = 'core' and c.relname in ('ads_metrics', 'paginas_ga4', 'ads_thumbnails'))
    or (n.nspname = 'mkt_wep' and c.relname in ('wep_cadastro', 'wep_checkout', 'wep_vendas', 'dim_anuncios', 'wep_quiz', 'wep_pesquisa'))
  )
order by pg_total_relation_size(c.oid) desc;

-- ── 2) Índices existentes nessas tabelas ───────────────────────────────────
select
  schemaname || '.' || tablename as tabela,
  indexname,
  indexdef
from pg_indexes
where (schemaname = 'core' and tablename in ('ads_metrics', 'paginas_ga4'))
   or (schemaname = 'mkt_wep' and tablename in ('wep_cadastro', 'wep_checkout', 'wep_vendas', 'dim_anuncios'))
order by tabela, indexname;

-- ── 3) Onde o tempo vai na fn_trafego ──────────────────────────────────────
-- Interessa o "Seq Scan" em tabela grande e o tempo de cada nó.
explain (analyze, buffers, format text)
select * from mkt_wep.fn_trafego(current_date - 30, current_date);

-- ── 4) Onde o tempo vai na leitura do GA4 ──────────────────────────────────
explain (analyze, buffers, format text)
select data, pagina, sum(page_views)
  from mkt_wep.vw_paginas_diario
 where data between current_date - 30 and current_date
 group by data, pagina;
