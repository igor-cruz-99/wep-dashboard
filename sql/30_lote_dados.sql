-- ============================================================================
-- LOTE DE DADOS — liga as métricas que faltavam (grupo padrão, séries por dia,
-- SEAL detalhado). Roda por último. Ordem da fn_kpis: 21 → 23 → 24 → 27 → 30.
--
-- 1) fn_kpis + p_grupo         → Entrada Grupo por etapa (pre_venda / padrao).
-- 2) fn_serie_grupo (nova)     → entradas no grupo por dia (por grupo).
-- 3) fn_serie_diaria + pesquisa→ respostas de pesquisa por dia.
-- 4) fn_seal_compradores +     → data, hora, term, página (tabela detalhada SEAL);
--                                prioriza a linha de complemento/integral (esconde
--                                a taxa de quem já quitou).
-- ============================================================================

-- ── 1) fn_kpis + p_grupo ────────────────────────────────────────────────────
drop function if exists mkt_wep.fn_kpis(text, date, date);
drop function if exists mkt_wep.fn_kpis(text, date, date, text);
drop function if exists mkt_wep.fn_kpis(text, date, date, text, text);
create function mkt_wep.fn_kpis(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_grupo text default null
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
  ),
  -- Entradas no grupo: filtra pelo GRUPO (pre_venda/padrao) e, no recorte parcial
  -- de origem, atribui pelo tel_8d do lead.
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

-- ── 2) fn_serie_grupo — entradas no grupo por dia (por grupo) ────────────────
drop function if exists mkt_wep.fn_serie_grupo(date, date, text);
create function mkt_wep.fn_serie_grupo(
  p_from date default null,
  p_to date default null,
  p_grupo text default null
)
returns table (data date, entradas bigint)
language sql
stable
as $$
  select data_entrada as data, count(*) as entradas
  from mkt_wep.wep_grupos
  where (p_from is null or data_entrada >= p_from)
    and (p_to   is null or data_entrada <= p_to)
    and (p_grupo is null or grupo = p_grupo)
  group by data_entrada
  order by data_entrada;
$$;

-- ── 3) fn_serie_diaria + pesquisa por dia ───────────────────────────────────
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

-- ── 4) fn_seal_compradores + data/hora/term/página (linha de complemento) ────
drop function if exists mkt_wep.fn_seal_compradores(date, date);
create function mkt_wep.fn_seal_compradores(
  p_from date default null,
  p_to date default null
)
returns table (
  email        text,
  nome         text,
  situacao     text,
  data         date,
  hora         time,
  utm_source   text,
  utm_campaign text,
  utm_medium   text,
  utm_content  text,
  utm_term     text,
  utm_pagina   text
)
language sql
stable
as $$
  with seal_rows as (
    select
      lower(btrim(email)) as email,
      nome_completo, data, hora,
      last_utm_source, last_utm_campaign, last_utm_medium,
      last_utm_content, last_utm_term, last_utm_pagina,
      -- prioridade da linha exibida: complemento/integral > taxa; depois com utm; depois recente.
      (produto ilike '%complemento%'
       or (produto ilike '%seal%' and produto not ilike '%complemento%' and produto not ilike '%taxa de reserva%')) as eh_quitacao,
      (last_utm_campaign is not null and btrim(last_utm_campaign) <> '') as tem_utm
    from core.vendas_pagarme
    where status = 'paid'
      and produto ilike '%seal%'
      and email is not null and btrim(email) <> ''
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  melhor as (
    select distinct on (email)
      email, nome_completo, data, hora,
      last_utm_source, last_utm_campaign, last_utm_medium,
      last_utm_content, last_utm_term, last_utm_pagina
    from seal_rows
    order by email, eh_quitacao desc, tem_utm desc, data desc nulls last, hora desc nulls last
  )
  select
    m.email,
    nullif(btrim(m.nome_completo), '') as nome,
    a.situacao,
    m.data,
    m.hora,
    m.last_utm_source, m.last_utm_campaign, m.last_utm_medium,
    m.last_utm_content, m.last_utm_term, m.last_utm_pagina
  from melhor m
  join mkt_wep.fn_seal_alunos(p_from, p_to) a on a.email = m.email
  order by a.situacao, m.data desc nulls last;
$$;
