-- ============================================================================
-- EXCLUIR CAMPANHA(S) DA VISÃO — roda por último.
--
-- Contexto: na etapa PADRÃO não queremos a campanha de remarketing de lote zero
-- (ls-WEP-WEPAGO26-p04-RMKT-lote-zero) contando em NADA da página — nem no card
-- Investimento, nem no funil (alcance/impressões/cliques), nem na tabela de
-- tráfego. Antes ela só sumia da tabela (filtro no front), mas os agregados do
-- ad spend continuavam somando.
--
-- Solução: um parâmetro novo `p_excluir text[]` nas RPCs que agregam ad spend.
--   null / vazio → sem exclusão (comportamento de hoje; Meteórico não manda).
--   ['ls-...']   → remove essas campanhas de vw_ads_diario (e da tabela de
--                  tráfego). O front manda a lista só quando é a etapa Padrão.
--
-- Onde a campanha aparece = vw_ads_diario.campanha (gasto, alcance, impressões,
-- cliques). É uma campanha de REMARKETING: não tem página de captura nem gera
-- leads (0 no período), então o corte é no ad spend — leads/páginas/vendas não
-- têm contribuição dessa campanha para remover.
--
-- ⚠️ Param novo → o Postgres cria uma sobrecarga nova. DROP das assinaturas
--    atuais antes de recriar (senão as chamadas por nome ficam ambíguas).
--
-- Ordem da fn_kpis: 21 → 23 → 24 → 27 → 30 → 31.
-- ============================================================================

-- ── 1) fn_kpis + p_excluir ──────────────────────────────────────────────────
drop function if exists mkt_wep.fn_kpis(text, date, date, text, text);
create function mkt_wep.fn_kpis(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_grupo text default null,
  p_excluir text[] default null
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
  meta_cpl           numeric,
  base_qualificacao  bigint
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
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and campanha ilike '%forms-nativo%')
           or (p_origem = 'pagina' and (campanha is null or campanha not ilike '%forms-nativo%')))
      -- exclui campanhas pedidas (ex.: RMKT lote-zero no Padrão)
      and (p_excluir is null or campanha is null or not (campanha = any(p_excluir)))
  ),
  g as (
    select count(*) as ent
    from mkt_wep.wep_grupos gr
    where (p_tag is null or gr.tag = p_tag)
      and (p_from is null or gr.data_entrada >= p_from)
      and (p_to   is null or gr.data_entrada <= p_to)
      and (p_grupo is null or gr.grupo = p_grupo)
      and (p_origem is null or p_origem = 'todas'
           or exists (
             select 1 from mkt_wep.wep_cadastro c
             where c.tel_8d = gr.tel_8d
               and (
                 (p_origem = 'nativo' and c.utm_pagina = 'Forms_nativo')
                 or (p_origem = 'pagina' and coalesce(c.utm_pagina, '') <> 'Forms_nativo')
               )
           ))
  ),
  p as (
    select coalesce(sum(pesquisas), 0) as pq
    from mkt_wep.vw_pesquisa_diario
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  qelig as (
    select lower(btrim(email)) as email, (qualificacao = '1') as q
    from mkt_wep.wep_pesquisa
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and email is not null and btrim(email) <> ''
      and coalesce(p_origem, 'todas') in ('todas', 'pagina')
    union all
    select lower(btrim(email)) as email, (qualificacao = '1') as q
    from mkt_wep.wep_cadastro
    where utm_pagina = 'Forms_nativo'
      and (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and email is not null and btrim(email) <> ''
      and coalesce(p_origem, 'todas') in ('todas', 'nativo')
  ),
  qdd as (
    select email, bool_or(q) as qualificado
    from qelig
    group by email
  ),
  qz as (
    select
      count(*) filter (where qualificado) as qualificados,
      count(*)                            as base
    from qdd
  ),
  l as (
    select count(*) as leads
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
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
    g.ent, p.pq, qz.qualificados, l.leads,
    t.mv, t.mf, t.mc, t.mg, t.mq, t.ml, t.mi, t.mcpl,
    qz.base
  from v, a, g, p, qz, l, t;
$$;

-- ── 2) fn_serie_diaria + p_excluir ──────────────────────────────────────────
drop function if exists mkt_wep.fn_serie_diaria(text, date, date, text);
create function mkt_wep.fn_serie_diaria(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_excluir text[] default null
)
returns table (
  data date,
  vendas int,
  investimento numeric,
  cac numeric,
  conversao numeric,
  leads int,
  page_views bigint,
  pesquisa bigint
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
      and (p_excluir is null or campanha is null or not (campanha = any(p_excluir)))
    group by data
  ),
  pv as (
    select data, sum(page_views) as page_views
    from mkt_wep.vw_paginas_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
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
  ),
  pq as (
    select data, sum(pesquisas) as pesquisa
    from mkt_wep.vw_pesquisa_diario
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
    case when coalesce(ck.checkouts, 0) > 0
         then round(100.0 * coalesce(vd.vendas, 0) / ck.checkouts, 2) else 0 end as conversao,
    coalesce(ld.leads, 0)      as leads,
    coalesce(pv.page_views, 0) as page_views,
    coalesce(pq.pesquisa, 0)   as pesquisa
  from (
    select data from vd
    union select data from ad
    union select data from pv
    union select data from ck
    union select data from ld
    union select data from pq
  ) d
  left join vd on vd.data = d.data
  left join ad on ad.data = d.data
  left join pv on pv.data = d.data
  left join ck on ck.data = d.data
  left join ld on ld.data = d.data
  left join pq on pq.data = d.data
  order by d.data;
$$;

-- ── 3) fn_funil + p_excluir ─────────────────────────────────────────────────
drop function if exists mkt_wep.fn_funil(text, date, date, text);
create function mkt_wep.fn_funil(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_excluir text[] default null
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
      and (p_excluir is null or campanha is null or not (campanha = any(p_excluir)))
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

-- ── 4) fn_trafego + p_excluir ───────────────────────────────────────────────
drop function if exists mkt_wep.fn_trafego(date, date, text);
create function mkt_wep.fn_trafego(
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_excluir text[] default null
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
    and (p_origem is null or p_origem = 'todas'
         or (p_origem = 'nativo' and ads.campanha ilike '%forms-nativo%')
         or (p_origem = 'pagina' and ads.campanha not ilike '%forms-nativo%'))
    -- exclui campanhas pedidas (e seus conjuntos/anúncios) na etapa que mandar a lista
    and (p_excluir is null or ads.campanha is null or not (ads.campanha = any(p_excluir)))
  order by ads.campanha, ads.conjunto nulls first, ads.anuncio nulls first;
$$;
