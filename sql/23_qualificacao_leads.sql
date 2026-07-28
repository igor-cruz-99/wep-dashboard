-- ============================================================================
-- NOVA QUALIFICAÇÃO — roda DEPOIS do 21_origem.sql e do 22_cadastro_renda.sql.
--
-- Regra nova (diretoria): qualificado = pessoa com renda > 10k, e a renda pode
-- vir de DUAS fontes:
--   • captação (wep_cadastro.qualificacao = '1' — preenchido pelo Make)
--   • pesquisa  (wep_pesquisa.qualificacao = '1' — já existia)
-- E o denominador muda: Qualificação (%) = qualificados ÷ LEADS
--   (antes era ÷ respostas da pesquisa).
--
-- Modelo pra não contar ninguém 2x: parto dos LEADS (wep_cadastro) e considero
-- qualificado quem bate o critério no próprio cadastro OU numa resposta de
-- pesquisa casada pelo EMAIL (normalizado: lower + sem espaços). Uso EXISTS
-- (não join) pra um lead com várias respostas não virar contagem dobrada.
--
-- Efeito colateral bom: como agora nasce da wep_cadastro (que tem utm_pagina),
-- a Qualificação passa a ser SEGMENTÁVEL POR ORIGEM (sai do "—" no recorte).
--
-- Só a fn_kpis muda. Mantém a MESMA assinatura e retorno do 21 (16 colunas) →
-- mas dropo as duas assinaturas antes por segurança (3 e 4 args).
--
-- ⚠️ Rode o 21 ANTES deste. Este é a palavra final da fn_kpis; se um dia
--    reaplicar o 21 depois, ele volta a Qualificação pro modelo antigo — então
--    a ordem é 21 → 23.
-- ============================================================================
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
  g as (
    select coalesce(sum(entradas), 0) as ent
    from mkt_wep.vw_grupos_diario
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  -- Respostas da pesquisa (para o resumo do bloco Pesquisa) — só a contagem.
  p as (
    select coalesce(sum(pesquisas), 0) as pq
    from mkt_wep.vw_pesquisa_diario
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  -- Qualificados = LEADS que batem o critério (cadastro OU pesquisa por email).
  -- Respeita tag + período + origem (mesma base dos leads).
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
