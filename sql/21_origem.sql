-- ============================================================================
-- FILTRO DE ORIGEM (Páginas vs Formulário nativo) — roda por último.
--
-- Contexto: teste A/B de captação. Duas páginas (v1/v2) + um formulário nativo
-- do Facebook (Lead Ads). Queremos ver as métricas separadas por ORIGEM.
--
-- A chave de origem existe em duas fontes, cada uma com sua coluna:
--   • LEADS  (wep_cadastro): pela coluna utm_pagina
--         nativo  = utm_pagina = 'Forms_nativo'
--         pagina  = qualquer outra (v1, v2, etc.)
--   • GASTO/ADS (vw_ads_diario): pelo NOME da campanha
--         nativo  = campanha ILIKE '%forms-nativo%'   (ex.: ls-WEP-WEPAGO26-p04-FORMS-NATIVO)
--         pagina  = o resto
--
-- ⚠️ O tráfego (impressões, cliques, alcance, gasto) NÃO dá pra separar entre
--    v1 e v2 — o gerenciador só distingue no nível da campanha. Por isso o corte
--    é 2 vias: PÁGINAS (v1+v2 juntas) vs NATIVO.
--
-- Parâmetro novo: p_origem text default null
--     null / 'todas' → sem filtro (comportamento de hoje)
--     'pagina'       → só páginas
--     'nativo'       → só formulário nativo
--
-- O que NÃO tem dimensão de origem e permanece TOTAL (o front mostra "—" quando
-- o recorte é parcial, pra ninguém ler um total achando que é o segmento):
--   • Vendas / Checkouts (não têm origem no modelo atual; no meteórico = 0)
--   • Entrada no grupo e Qualificados (Fase 2: dependem de telefone/renda)
--
-- page_views vêm do GA4 (páginas reais) → para 'nativo' são 0 por definição
-- (o formulário nativo não tem página de captura).
--
-- ⚠️ Todas ganham parâmetro novo → o Postgres cria uma sobrecarga nova e as
--    chamadas com nomes ficariam ambíguas. Por isso DROP das assinaturas antigas
--    antes de recriar.
-- ============================================================================

-- ── 1) fn_kpis ──────────────────────────────────────────────────────────────
-- origem entra em: leads (utm_pagina) e investimento (campanha).
-- vendas/faturamento/grupo/pesquisa ficam totais (front blanca no recorte).
drop function if exists mkt_wep.fn_kpis(text, date, date);
drop function if exists mkt_wep.fn_kpis(text, date, date, text);
create function mkt_wep.fn_kpis(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null
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
  meta_investimento  numeric,
  meta_cpl           numeric
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
      -- origem pela campanha
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and campanha ilike '%forms-nativo%')
           or (p_origem = 'pagina' and (campanha is null or campanha not ilike '%forms-nativo%')))
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
      -- origem pela utm_pagina
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and utm_pagina = 'Forms_nativo')
           or (p_origem = 'pagina' and coalesce(utm_pagina, '') <> 'Forms_nativo'))
  ),
  t as (
    select
      coalesce(sum(meta_vendas), 0)       as mv,
      coalesce(sum(meta_faturamento), 0)  as mf,
      coalesce(sum(meta_cac), 0)          as mc,
      coalesce(sum(meta_grupo), 0)        as mg,
      coalesce(sum(meta_qualificacao),0)  as mq,
      coalesce(sum(meta_leads), 0)        as ml,
      coalesce(sum(meta_investimento), 0) as mi,
      coalesce(sum(meta_cpl), 0)          as mcpl
    from mkt_wep.vw_tags
    where (p_tag is null or tag = p_tag)
  )
  select
    v.c, v.fat, a.gasto,
    case when v.c > 0 then round(a.gasto / v.c, 2) else 0 end,
    g.ent, p.pq, p.ql, l.leads,
    t.mv, t.mf, t.mc, t.mg, t.mq, t.ml, t.mi, t.mcpl
  from v, a, g, p, l, t;
$$;

-- ── 2) fn_serie_diaria ──────────────────────────────────────────────────────
-- origem em: leads (utm_pagina), investimento (campanha) e page_views
-- (nativo → 0, pois o formulário nativo não tem página).
drop function if exists mkt_wep.fn_serie_diaria(text, date, date);
drop function if exists mkt_wep.fn_serie_diaria(text, date, date, text);
create function mkt_wep.fn_serie_diaria(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null
)
returns table (
  data date,
  vendas int,
  investimento numeric,
  cac numeric,
  conversao numeric,
  leads int,
  page_views bigint
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
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and campanha ilike '%forms-nativo%')
           or (p_origem = 'pagina' and (campanha is null or campanha not ilike '%forms-nativo%')))
    group by data
  ),
  pv as (
    select data, sum(page_views) as page_views
    from mkt_wep.vw_paginas_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      -- nativo não tem página → sem page views
      and (p_origem is null or p_origem <> 'nativo')
    group by data
  ),
  ck as (
    select data, count(*) as checkouts
    from mkt_wep.vw_checkouts
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by data
  ),
  ld as (
    select data, count(*) as leads
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and utm_pagina = 'Forms_nativo')
           or (p_origem = 'pagina' and coalesce(utm_pagina, '') <> 'Forms_nativo'))
    group by data
  )
  select
    d.data,
    coalesce(vd.vendas, 0)  as vendas,
    coalesce(ad.gasto, 0)   as investimento,
    case when coalesce(vd.vendas, 0) > 0
         then round(coalesce(ad.gasto, 0) / vd.vendas, 2) else 0 end as cac,
    case when coalesce(ck.checkouts, 0) > 0
         then round(100.0 * coalesce(vd.vendas, 0) / ck.checkouts, 2) else 0 end as conversao,
    coalesce(ld.leads, 0)      as leads,
    coalesce(pv.page_views, 0) as page_views
  from (
    select data from vd
    union select data from ad
    union select data from pv
    union select data from ck
    union select data from ld
  ) d
  left join vd on vd.data = d.data
  left join ad on ad.data = d.data
  left join pv on pv.data = d.data
  left join ck on ck.data = d.data
  left join ld on ld.data = d.data
  order by d.data;
$$;

-- ── 3) fn_funil ─────────────────────────────────────────────────────────────
-- origem em: ads (gasto/alcance/impressões/cliques via campanha), page_views
-- (nativo → 0) e leads (utm_pagina). Checkouts/Vendas ficam totais (no
-- meteórico = 0; não há origem atribuível a venda no modelo atual).
drop function if exists mkt_wep.fn_funil(text, date, date);
drop function if exists mkt_wep.fn_funil(text, date, date, text);
create function mkt_wep.fn_funil(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null
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
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and campanha ilike '%forms-nativo%')
           or (p_origem = 'pagina' and (campanha is null or campanha not ilike '%forms-nativo%')))
  ),
  pv as (
    select coalesce(sum(page_views), 0) as page_views
    from mkt_wep.vw_paginas_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and (p_origem is null or p_origem <> 'nativo')
  ),
  ld as (
    select count(*) as leads
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and utm_pagina = 'Forms_nativo')
           or (p_origem = 'pagina' and coalesce(utm_pagina, '') <> 'Forms_nativo'))
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

-- ── 4) fn_trafego ───────────────────────────────────────────────────────────
-- origem pela campanha: 'nativo' mostra só a campanha FORMS-NATIVO; 'pagina'
-- esconde ela. Leads/vendas seguem a mesma linha via as UTMs.
drop function if exists mkt_wep.fn_trafego(date, date);
drop function if exists mkt_wep.fn_trafego(date, date, text);
create function mkt_wep.fn_trafego(
  p_from date default null,
  p_to date default null,
  p_origem text default null
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
    -- filtro de origem pela campanha
    and (p_origem is null or p_origem = 'todas'
         or (p_origem = 'nativo' and ads.campanha ilike '%forms-nativo%')
         or (p_origem = 'pagina' and ads.campanha not ilike '%forms-nativo%'))
  order by ads.campanha, ads.conjunto nulls first, ads.anuncio nulls first;
$$;

-- ── 5) fn_paginas ───────────────────────────────────────────────────────────
-- origem pela utm_pagina dos leads e pela existência de página no GA4:
--   'nativo' → só a linha Forms_nativo (sem page views);
--   'pagina' → páginas reais, sem a linha do nativo.
drop function if exists mkt_wep.fn_paginas(date, date);
drop function if exists mkt_wep.fn_paginas(date, date, text);
create function mkt_wep.fn_paginas(
  p_from date default null,
  p_to date default null,
  p_origem text default null
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
      -- nativo não tem página real no GA4
      and (p_origem is null or p_origem <> 'nativo')
    group by pagina
  ),
  lds as (
    select mkt_wep.norm_pagina(utm_pagina) as pagina, count(*) as leads
    from mkt_wep.wep_cadastro
    where utm_pagina is not null and btrim(utm_pagina) <> ''
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and utm_pagina = 'Forms_nativo')
           or (p_origem = 'pagina' and coalesce(utm_pagina, '') <> 'Forms_nativo'))
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
  where coalesce(b.pagina, l.pagina) not ilike '%tkp%'
  order by page_views desc;
$$;
