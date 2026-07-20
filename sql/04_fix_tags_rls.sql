-- ============================================================================
-- Correção: anon não lê wep_tags direto (RLS). Expõe via view e faz a
-- fn_kpis ler as metas dessa view. Rode este arquivo inteiro uma vez.
-- ============================================================================

-- 1) View das tags (roda como owner, ignora RLS — igual às demais views)
create or replace view mkt_wep.vw_tags as
select * from mkt_wep.wep_tags;

grant select on mkt_wep.vw_tags to anon, authenticated;

-- 2) fn_kpis passa a ler as metas de vw_tags (resto igual)
create or replace function mkt_wep.fn_kpis(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (
  vendas_count      bigint,
  faturamento       numeric,
  investimento      numeric,
  cac               numeric,
  entradas_grupo    bigint,
  pesquisas         bigint,
  qualificados      bigint,
  meta_vendas       numeric,
  meta_faturamento  numeric,
  meta_cac          numeric,
  meta_grupo        numeric,
  meta_qualificacao numeric
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
  t as (
    select
      coalesce(sum(meta_vendas), 0)      as mv,
      coalesce(sum(meta_faturamento), 0) as mf,
      coalesce(sum(meta_cac), 0)         as mc,
      coalesce(sum(meta_grupo), 0)       as mg,
      coalesce(sum(meta_qualificacao),0) as mq
    from mkt_wep.vw_tags
    where (p_tag is null or tag = p_tag)
  )
  select
    v.c, v.fat, a.gasto,
    case when v.c > 0 then round(a.gasto / v.c, 2) else 0 end,
    g.ent, p.pq, p.ql,
    t.mv, t.mf, t.mc, t.mg, t.mq
  from v, a, g, p, t;
$$;
