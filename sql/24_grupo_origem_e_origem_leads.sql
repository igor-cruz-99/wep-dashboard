-- ============================================================================
-- ENTRADA GRUPO POR ORIGEM + TABELA "ORIGEM DOS LEADS" — roda DEPOIS do 23.
--
-- 1) fn_kpis: entradas_grupo passa a respeitar a origem, casando a entrada no
--    grupo (wep_grupos) com o lead (wep_cadastro) pelo tel_8d. Entradas orgânicas
--    (tel_8d sem lead correspondente) só aparecem em 'todas' — num recorte
--    parcial elas somem, porque não têm origem atribuível. Resto da fn_kpis =
--    igual ao 23 (qualificados por email ÷ leads, etc.).
--
-- 2) fn_origem_leads: nova RPC pra tabela "Origem dos Leads" — quantos leads
--    vieram de cada página/forms e o % sobre o total. Agrupa por utm_pagina
--    normalizado (Forms_nativo vira "Formulário nativo").
--
-- ⚠️ Ordem: 21 → 23 → 24. Este é a palavra final da fn_kpis.
-- ============================================================================

-- ── 1) fn_kpis (entradas_grupo por origem via tel_8d) ───────────────────────
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
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and campanha ilike '%forms-nativo%')
           or (p_origem = 'pagina' and (campanha is null or campanha not ilike '%forms-nativo%')))
  ),
  -- Entradas no grupo, atribuídas à origem pelo tel_8d do lead.
  g as (
    select count(*) as ent
    from mkt_wep.wep_grupos gr
    where (p_tag is null or gr.tag = p_tag)
      and (p_from is null or gr.data_entrada >= p_from)
      and (p_to   is null or gr.data_entrada <= p_to)
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
  ql as (
    select count(*) as qualificados
    from mkt_wep.wep_cadastro c
    where (p_tag is null or c.tag = p_tag)
      and (p_from is null or c.data >= p_from)
      and (p_to   is null or c.data <= p_to)
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and c.utm_pagina = 'Forms_nativo')
           or (p_origem = 'pagina' and coalesce(c.utm_pagina, '') <> 'Forms_nativo'))
      and (
        coalesce(c.qualificacao, '') = '1'
        or exists (
          select 1 from mkt_wep.wep_pesquisa pq
          where lower(btrim(pq.email)) = lower(btrim(c.email))
            and pq.qualificacao = '1'
        )
      )
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
    g.ent, p.pq, ql.qualificados, l.leads,
    t.mv, t.mf, t.mc, t.mg, t.mq, t.ml, t.mi, t.mcpl
  from v, a, g, p, ql, l, t;
$$;

-- ── 2) fn_origem_leads (tabela "Origem dos Leads") ──────────────────────────
drop function if exists mkt_wep.fn_origem_leads(text, date, date, text);
create function mkt_wep.fn_origem_leads(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null
)
returns table (origem text, leads bigint, pct numeric)
language sql
stable
as $$
  with base as (
    select
      case
        when utm_pagina = 'Forms_nativo' then 'Formulário nativo'
        when utm_pagina is null or btrim(utm_pagina) = '' then '(sem origem)'
        else mkt_wep.norm_pagina(utm_pagina)
      end as origem,
      count(*) as leads
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and utm_pagina = 'Forms_nativo')
           or (p_origem = 'pagina' and coalesce(utm_pagina, '') <> 'Forms_nativo'))
    group by 1
  ),
  tot as (select coalesce(sum(leads), 0) as t from base)
  select
    b.origem,
    b.leads,
    case when tot.t > 0 then round(100.0 * b.leads / tot.t, 1) else 0 end as pct
  from base b, tot
  order by b.leads desc, b.origem;
$$;
