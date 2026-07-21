-- ============================================================================
-- META DE INVESTIMENTO — roda DEPOIS do 11_leads.sql.
--
-- Novo card "Investimento" no topo do painel. O VALOR (gasto) já vinha da
-- fn_kpis; aqui só acrescentamos a META, vinda da coluna meta_investimento
-- que você criou em wep_tags.
--
-- ⚠️ Mesmo detalhe do meta_leads: a vw_tags foi criada com `select *` e o
--    Postgres congela as colunas — precisamos recriar a view para ela enxergar
--    meta_investimento, senão a fn_kpis falha.
-- ============================================================================

-- 1) Garante a coluna + refresca a view (não sobrescreve seus valores).
alter table mkt_wep.wep_tags add column if not exists meta_investimento numeric;
create or replace view mkt_wep.vw_tags as select * from mkt_wep.wep_tags;

-- 2) fn_kpis (+ meta_investimento) -------------------------------------------
drop function if exists mkt_wep.fn_kpis(text, date, date);
create function mkt_wep.fn_kpis(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (
  vendas_count       bigint,
  faturamento        numeric,
  investimento       numeric,
  cac                numeric,
  entradas_grupo     bigint,
  pesquisas          bigint,
  qualificados       bigint,
  leads              bigint,
  meta_vendas        numeric,
  meta_faturamento   numeric,
  meta_cac           numeric,
  meta_grupo         numeric,
  meta_qualificacao  numeric,
  meta_leads         numeric,
  meta_investimento  numeric
)
language sql
stable
as $$
  with v as (
    select
      count(*) filter (where venda_valida)                as c,
      coalesce(sum(valor) filter (where venda_valida), 0) as fat
    from mkt_wep.vw_vendas
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  a as (
    select coalesce(sum(gasto), 0) as gasto
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  g as (
    select coalesce(sum(entradas), 0) as ent
    from mkt_wep.vw_grupos_diario
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  p as (
    select
      coalesce(sum(pesquisas), 0)    as pq,
      coalesce(sum(qualificados), 0) as ql
    from mkt_wep.vw_pesquisa_diario
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  l as (
    select count(*) as leads
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  t as (
    select
      coalesce(sum(meta_vendas), 0)       as mv,
      coalesce(sum(meta_faturamento), 0)  as mf,
      coalesce(sum(meta_cac), 0)          as mc,
      coalesce(sum(meta_grupo), 0)        as mg,
      coalesce(sum(meta_qualificacao),0)  as mq,
      coalesce(sum(meta_leads), 0)        as ml,
      coalesce(sum(meta_investimento), 0) as mi
    from mkt_wep.vw_tags
    where (p_tag is null or tag = p_tag)
  )
  select
    v.c, v.fat, a.gasto,
    case when v.c > 0 then round(a.gasto / v.c, 2) else 0 end,
    g.ent, p.pq, p.ql, l.leads,
    t.mv, t.mf, t.mc, t.mg, t.mq, t.ml, t.mi
  from v, a, g, p, l, t;
$$;
