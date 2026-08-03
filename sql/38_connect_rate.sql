-- ============================================================================
-- CONNECT RATE — métrica do funil (não da tabela de páginas: não existe
-- vínculo hoje entre "anúncio → URL exata" pra calcular por página).
--
-- Connect Rate = Visualizações da página de destino (Meta) ÷ Cliques no link
-- (Meta) × 100. Mostrado no funil, entre Cliques e Page Views.
--
-- landing_page_views/link_cliques já existem em core.ads_metrics (por isso
-- em vw_ads_diario) — só precisavam ser somados e expostos. Adicionados na
-- mesma CTE `a` que já soma investimento/alcance/impressões/cliques em
-- fn_kpis, respeitando os mesmos filtros de origem/exclusão.
-- ============================================================================
drop function if exists mkt_wep.fn_kpis(text, date, date, text, text, text[]);
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
  base_qualificacao  bigint,
  landing_page_views bigint,
  link_cliques       bigint
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
    select
      coalesce(sum(gasto), 0)               as gasto,
      coalesce(sum(landing_page_views), 0)  as lpv,
      coalesce(sum(link_cliques), 0)        as lc
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and campanha ilike '%forms-nativo%')
           or (p_origem = 'pagina' and (campanha is null or campanha not ilike '%forms-nativo%')))
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
    qz.base, a.lpv, a.lc
  from v, a, g, p, qz, l, t;
$$;
