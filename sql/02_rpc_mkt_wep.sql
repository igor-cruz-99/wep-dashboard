-- ============================================================================
-- WEP DASHBOARD — Funções RPC de agregação (schema mkt_wep)
-- Rodar DEPOIS do 01_views_mkt_wep.sql.
--
-- Por que RPC e não somar no front:
--   vw_ads_diario tem ~9.467 linhas e a API do Supabase corta em 1.000 por
--   request. Somar no navegador daria totais errados. Aqui o Postgres agrega
--   e devolve pronto. O front chama supabase.rpc('fn_...', { p_from, p_to }).
--
-- Convenção de filtros:
--   p_tag   text  -> filtra tabelas que têm 'tag' (vendas, grupos, pesquisa).
--                    NULL = todas as tags.
--   p_from  date  -> data inicial (inclusive). NULL = sem limite.
--   p_to    date  -> data final  (inclusive). NULL = sem limite.
--   ads_metrics e paginas_ga4 NÃO têm tag: são filtrados só por data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Metas por lançamento: adiciona as colunas que faltavam em wep_tags.
-- (idempotente — pode rodar quantas vezes quiser)
-- ----------------------------------------------------------------------------
alter table mkt_wep.wep_tags add column if not exists meta_faturamento   numeric;
alter table mkt_wep.wep_tags add column if not exists meta_cac           numeric;
alter table mkt_wep.wep_tags add column if not exists meta_grupo         numeric;
alter table mkt_wep.wep_tags add column if not exists meta_qualificacao  numeric;

-- ----------------------------------------------------------------------------
-- KPIs (agregados brutos + metas de wep_tags; percentuais calculados no front)
-- ----------------------------------------------------------------------------
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
      count(*) filter (where venda_valida)                       as c,
      coalesce(sum(valor) filter (where venda_valida), 0)        as fat
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

-- ----------------------------------------------------------------------------
-- FUNIL (uma linha por etapa, na ordem certa)
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- SÉRIE DIÁRIA (para os gráficos de linha).
-- Devolve, por dia: vendas, investimento e CAC.  -- conversão: ver TODO abaixo
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_serie_diaria(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (
  data date,
  vendas int,
  investimento numeric,
  cac numeric,
  conversao numeric
)
language sql
stable
as $$
  with vd as (
    select data, count(*) filter (where venda_valida) as vendas
    from mkt_wep.vw_vendas
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by data
  ),
  ad as (
    select data, sum(gasto) as gasto
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by data
  ),
  ck as (
    select data, count(*) as checkouts
    from mkt_wep.vw_checkouts
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by data
  )
  select
    d.data,
    coalesce(vd.vendas, 0)  as vendas,
    coalesce(ad.gasto, 0)   as investimento,
    case when coalesce(vd.vendas, 0) > 0
         then round(coalesce(ad.gasto, 0) / vd.vendas, 2) else 0 end as cac,
    -- Conversão = Vendas ÷ Checkouts (%)
    case when coalesce(ck.checkouts, 0) > 0
         then round(100.0 * coalesce(vd.vendas, 0) / ck.checkouts, 2) else 0 end as conversao
  from (
    select data from vd
    union select data from ad
    union select data from ck
  ) d
  left join vd on vd.data = d.data
  left join ad on ad.data = d.data
  left join ck on ck.data = d.data
  order by d.data;
$$;

-- ----------------------------------------------------------------------------
-- ANÁLISE DE TRÁFEGO (hierarquia campanha → conjunto → anúncio).
-- Hook/Hold/Body recalculados a partir das somas (mais correto que média de %).
-- vendas atribuídas por campanha/conjunto/anúncio (via UTM na vw_vendas).
-- Qualificação por campanha: NÃO disponível (pesquisa não tem UTM) -> null.
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_trafego(
  p_from date default null,
  p_to date default null
)
returns table (
  nivel text,
  campanha text,
  conjunto text,
  anuncio text,
  investimento numeric,
  vendas bigint,
  cac numeric,
  hook numeric,
  hold numeric,
  body numeric
)
language sql
stable
as $$
  with ads as (
    select campanha, conjunto, anuncio,
           sum(gasto) as gasto,
           sum(impressoes) as imp,
           sum(video_3s) as v3,
           sum(video_25p) as v25,
           sum(video_50p) as v50
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio))
  ),
  vds as (
    select campanha, conjunto, anuncio,
           count(*) filter (where venda_valida) as vendas
    from mkt_wep.vw_vendas
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio))
  )
  select
    case
      when ads.anuncio is not null then 'anuncio'
      when ads.conjunto is not null then 'conjunto'
      else 'campanha'
    end as nivel,
    ads.campanha, ads.conjunto, ads.anuncio,
    ads.gasto as investimento,
    coalesce(vds.vendas, 0) as vendas,
    case when coalesce(vds.vendas,0) > 0 then round(ads.gasto / vds.vendas, 2) else 0 end as cac,
    -- Hook = video_3s / impressões ; Hold = video_25% / video_3s ; Body = video_50% / impressões
    case when ads.imp > 0 then round(100.0 * ads.v3  / ads.imp, 1) else 0 end as hook,
    case when ads.v3  > 0 then round(100.0 * ads.v25 / ads.v3,  1) else 0 end as hold,
    case when ads.imp > 0 then round(100.0 * ads.v50 / ads.imp, 1) else 0 end as body
  from ads
  left join vds
    on  ads.campanha is not distinct from vds.campanha
    and ads.conjunto is not distinct from vds.conjunto
    and ads.anuncio  is not distinct from vds.anuncio
  where ads.campanha ilike '%wep%'
  order by ads.campanha, ads.conjunto nulls first, ads.anuncio nulls first;
$$;

-- ----------------------------------------------------------------------------
-- PÁGINAS (agrega vw_pagina_resumo por página no período; ratios no front)
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_paginas(
  p_from date default null,
  p_to date default null
)
returns table (
  pagina text,
  page_views bigint,
  checkouts bigint,
  vendas bigint
)
language sql
stable
as $$
  select
    pagina,
    coalesce(sum(page_views), 0) as page_views,
    coalesce(sum(checkouts), 0)  as checkouts,
    coalesce(sum(vendas), 0)     as vendas
  from mkt_wep.vw_pagina_resumo
  where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
  group by pagina
  order by page_views desc;
$$;

-- ----------------------------------------------------------------------------
-- Permissão de execução pra API
-- ----------------------------------------------------------------------------
grant execute on all functions in schema mkt_wep to anon, authenticated;
alter default privileges in schema mkt_wep
  grant execute on functions to anon, authenticated;
