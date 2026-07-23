-- ============================================================================
-- fn_funil: adiciona a etapa LEADS logo abaixo de Page Views.
--
-- Nova ordem: Investimento → Alcance → Impressões → Cliques → Page Views →
--             Leads → Checkouts → Vendas.
--
-- Leads vêm de wep_cadastro (mesma fonte do KPI/tráfego), filtrados por tag +
-- período. Retorno (etapa, valor, ordem) inalterado → create or replace.
-- ============================================================================
create or replace function mkt_wep.fn_funil(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (etapa text, valor numeric, ordem int)
language sql
stable
as $$
  with a as (
    select
      coalesce(sum(gasto), 0)      as investimento,
      coalesce(sum(alcance), 0)    as alcance,
      coalesce(sum(impressoes), 0) as impressoes,
      coalesce(sum(cliques), 0)    as cliques
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
  ),
  pv as (
    select coalesce(sum(page_views), 0) as page_views
    from mkt_wep.vw_paginas_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
  ),
  ld as (
    select count(*) as leads
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
  ),
  ck as (
    select count(*) as checkouts
    from mkt_wep.vw_checkouts
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
  ),
  vd as (
    select count(*) filter (where venda_valida) as vendas
    from mkt_wep.vw_vendas
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
  )
  select 'Investimento', a.investimento, 1 from a
  union all select 'Alcance',     a.alcance,     2 from a
  union all select 'Impressões',  a.impressoes,  3 from a
  union all select 'Cliques',     a.cliques,     4 from a
  union all select 'Page Views',  pv.page_views, 5 from pv
  union all select 'Leads',       ld.leads,      6 from ld
  union all select 'Checkouts',   ck.checkouts,  7 from ck
  union all select 'Vendas',      vd.vendas,     8 from vd
  order by 3;
$$;
