-- ============================================================================
-- O funil da etapa PADRÃO contava page view de TODA página, inclusive as de
-- captação — enquanto a tabela "Desempenho página de vendas" logo abaixo
-- contava só as de venda. No período do Padrão isso dava ~3.958 no funil contra
-- ~3.549 na tabela: 417 views de 17 páginas de captação
-- (/imersao-estrategista-patrimonial-lp01-h1 com 205, /wepago26-quizz com 35,
-- /wep-lp01-h1 com 31, entre outras).
--
-- Além de não bater com a tabela, distorce dois indicadores do próprio funil no
-- Padrão, que é venda direta: "Conversão página" e "CPLV" ficavam diluídos por
-- tráfego de página que nunca ia gerar checkout ali.
--
-- Correção: parâmetro p_so_vendas. Quando true, o Page Views:
--   1. sai da mkt_wep.vw_pagina_resumo (a MESMA fonte da tabela) e não da
--      vw_paginas_diario. Isso importa porque a vw_pagina_resumo já exclui as
--      páginas mortas listadas no sql/44 — sem isso sobrava uma diferença de
--      4 views em 2 páginas (wep-vend-h2 e wep-vend-h1-v2), e qualquer exclusão
--      futura teria que ser mantida em dois lugares;
--   2. conta só página de venda, com o mesmo critério do front: slug com
--      "vend"/"-pv-" OU a página teve checkout/venda no período. O segundo caso
--      existe porque a nomenclatura já mudou três vezes e as LPs novas
--      (wep-lp02-h1-v1) não casam com padrão de slug nenhum.
--
-- Default false: sem o parâmetro a função se comporta exatamente como antes,
-- lendo da vw_paginas_diario. Meteórico e SEAL não mudam.
-- ============================================================================
drop function if exists mkt_wep.fn_funil(text, date, date, text, text[]);
drop function if exists mkt_wep.fn_funil(text, date, date, text, text[], boolean);
create function mkt_wep.fn_funil(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_excluir text[] default null,
  p_so_vendas boolean default false
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
  -- Só página de venda, agregada por página no período (igual a tabela faz).
  pv_vendas as (
    select coalesce(sum(t.views), 0) as page_views
    from (
      select r.pagina,
             sum(r.page_views) as views,
             sum(r.checkouts)  as ck,
             sum(r.vendas)     as vd
        from mkt_wep.vw_pagina_resumo r
       where (p_from is null or r.data >= p_from)
         and (p_to   is null or r.data <= p_to)
       group by r.pagina
    ) t
    where t.pagina ~* '(vend|-pv-)' or t.ck > 0 or t.vd > 0
  ),
  -- Comportamento antigo: todas as páginas.
  pv_todas as (
    select coalesce(sum(page_views), 0) as page_views
    from mkt_wep.vw_paginas_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
  ),
  pv as (
    select case
             -- o recorte "Forms nativo" não tem page view de página
             when p_origem = 'nativo' then 0
             when coalesce(p_so_vendas, false) then (select page_views from pv_vendas)
             else (select page_views from pv_todas)
           end as page_views
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

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) O MESMO número nos dois lugares. As duas linhas devem ser IGUAIS:
--     (a de cima é o funil; a de baixo é o total da tabela de vendas)
select 'funil (p_so_vendas)' as origem, valor as page_views
  from mkt_wep.fn_funil(null, '2026-07-31', '2026-08-21', null, null, true)
 where etapa = 'Page Views'
union all
select 'tabela de vendas', coalesce(sum(t.views), 0)
  from (
    select r.pagina, sum(r.page_views) as views,
           sum(r.checkouts) as ck, sum(r.vendas) as vd
      from mkt_wep.vw_pagina_resumo r
     where r.data between '2026-07-31' and '2026-08-21'
     group by r.pagina
  ) t
 where t.pagina ~* '(vend|-pv-)' or t.ck > 0 or t.vd > 0;

-- (b) Sem o parâmetro nada muda (Meteórico/SEAL seguem iguais):
select valor as page_views_sem_param
  from mkt_wep.fn_funil(null, '2026-07-31', '2026-08-21')
 where etapa = 'Page Views';

-- (c) Só Page Views pode diferir entre as duas chamadas (esperado: 1 linha):
select f1.etapa, f1.valor as sem_param, f2.valor as com_param
  from mkt_wep.fn_funil(null, '2026-07-31', '2026-08-21') f1
  join mkt_wep.fn_funil(null, '2026-07-31', '2026-08-21', null, null, true) f2
    on f2.etapa = f1.etapa
 where f1.valor is distinct from f2.valor;
