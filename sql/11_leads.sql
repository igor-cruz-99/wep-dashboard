-- ============================================================================
-- LEADS (nova estratégia de captação) — roda DEPOIS do 10_table_wep_cadastro.
--
-- 1) Meta de leads em wep_tags (200 por tag).
-- 2) fn_kpis: passa a devolver `leads` + `meta_leads` (contador do KPI).
-- 3) fn_trafego: nova coluna `leads` por campanha (via utm_campaign).
--
-- ⚠️ fn_kpis e fn_trafego MUDAM o retorno → o Postgres não deixa
--    `create or replace` alterar colunas de saída, então dropamos antes.
-- ============================================================================

-- 1) META DE LEADS ------------------------------------------------------------
-- A coluna é gerenciada por você direto na tabela wep_tags (preencha 200 por
-- tag ali). O `if not exists` é só para a fn_kpis abaixo poder ser criada mesmo
-- se a coluna ainda não existir — NÃO sobrescreve valores que você já pôs.
alter table mkt_wep.wep_tags add column if not exists meta_leads numeric;

-- IMPORTANTE: vw_tags foi criada com `select *`, e o Postgres congela o `*` nas
-- colunas de quando a view nasceu. Sem recriar, a view NÃO enxerga meta_leads
-- e a fn_kpis abaixo falha ("column meta_leads does not exist"). Recriar resolve.
create or replace view mkt_wep.vw_tags as select * from mkt_wep.wep_tags;

-- 2) fn_kpis (+ leads, + meta_leads) -----------------------------------------
drop function if exists mkt_wep.fn_kpis(text, date, date);
create function mkt_wep.fn_kpis(
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
  leads             bigint,
  meta_vendas       numeric,
  meta_faturamento  numeric,
  meta_cac          numeric,
  meta_grupo        numeric,
  meta_qualificacao numeric,
  meta_leads        numeric
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
  -- Contador de leads: todas as linhas de cadastro no filtro (tag + período).
  l as (
    select count(*) as leads
    from mkt_wep.wep_cadastro
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
      coalesce(sum(meta_qualificacao),0) as mq,
      coalesce(sum(meta_leads), 0)       as ml
    from mkt_wep.vw_tags
    where (p_tag is null or tag = p_tag)
  )
  select
    v.c, v.fat, a.gasto,
    case when v.c > 0 then round(a.gasto / v.c, 2) else 0 end,
    g.ent, p.pq, p.ql, l.leads,
    t.mv, t.mf, t.mc, t.mg, t.mq, t.ml
  from v, a, g, p, l, t;
$$;

-- 3) fn_trafego (+ leads por campanha/conjunto/anúncio) ----------------------
-- Leads atribuídos pelas UTMs, MESMA lógica das vendas: join do cadastro em
-- dim_anuncios por (utm_campaign = campanha) e (utm_content = anúncio). Assim
-- os leads somam nos três níveis (campanha, conjunto, anúncio).
drop function if exists mkt_wep.fn_trafego(date, date);
create function mkt_wep.fn_trafego(
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
  leads bigint,
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
  ),
  -- Leads atribuídos por UTM nos 3 níveis (igual a vds): o cadastro entra em
  -- dim_anuncios por campanha (utm_campaign) + anúncio (utm_content), e daí sai
  -- o conjunto. Leads sem match num anúncio WEP não entram (mesmo critério das vendas).
  lds as (
    select d.campanha, d.conjunto, d.anuncio, count(*) as leads
    from mkt_wep.wep_cadastro c
    join mkt_wep.dim_anuncios d
      on  c.utm_campaign = d.campanha
      and c.utm_content  = d.anuncio
    where (p_from is null or c.data >= p_from) and (p_to is null or c.data <= p_to)
    group by grouping sets ((d.campanha), (d.campanha, d.conjunto), (d.campanha, d.conjunto, d.anuncio))
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
    coalesce(lds.leads, 0) as leads,
    case when coalesce(vds.vendas,0) > 0 then round(ads.gasto / vds.vendas, 2) else 0 end as cac,
    case when ads.imp > 0 then round(100.0 * ads.v3  / ads.imp, 1) else 0 end as hook,
    case when ads.v3  > 0 then round(100.0 * ads.v25 / ads.v3,  1) else 0 end as hold,
    case when ads.imp > 0 then round(100.0 * ads.v50 / ads.imp, 1) else 0 end as body
  from ads
  left join vds
    on  ads.campanha is not distinct from vds.campanha
    and ads.conjunto is not distinct from vds.conjunto
    and ads.anuncio  is not distinct from vds.anuncio
  left join lds
    on  ads.campanha is not distinct from lds.campanha
    and ads.conjunto is not distinct from lds.conjunto
    and ads.anuncio  is not distinct from lds.anuncio
  where ads.campanha ilike '%wep%'
  order by ads.campanha, ads.conjunto nulls first, ads.anuncio nulls first;
$$;

-- 4) fn_paginas (+ leads por página) -----------------------------------------
-- Leads por página via utm_pagina (caminho normalizado, mesma norm_pagina das
-- outras métricas). FULL JOIN para uma página que só tenha leads também aparecer.
drop function if exists mkt_wep.fn_paginas(date, date);
create function mkt_wep.fn_paginas(
  p_from date default null,
  p_to date default null
)
returns table (
  pagina text,
  page_views bigint,
  checkouts bigint,
  vendas bigint,
  leads bigint
)
language sql
stable
as $$
  with base as (
    select
      pagina,
      coalesce(sum(page_views), 0) as page_views,
      coalesce(sum(checkouts), 0)  as checkouts,
      coalesce(sum(vendas), 0)     as vendas
    from mkt_wep.vw_pagina_resumo
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by pagina
  ),
  lds as (
    select mkt_wep.norm_pagina(utm_pagina) as pagina, count(*) as leads
    from mkt_wep.wep_cadastro
    where utm_pagina is not null and btrim(utm_pagina) <> ''
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by mkt_wep.norm_pagina(utm_pagina)
  )
  select
    coalesce(b.pagina, l.pagina)  as pagina,
    coalesce(b.page_views, 0)     as page_views,
    coalesce(b.checkouts, 0)      as checkouts,
    coalesce(b.vendas, 0)         as vendas,
    coalesce(l.leads, 0)          as leads
  from base b
  full join lds l on b.pagina = l.pagina
  where coalesce(b.pagina, l.pagina) not ilike '%tkp%'  -- fora as páginas de obrigado
  order by page_views desc;
$$;
