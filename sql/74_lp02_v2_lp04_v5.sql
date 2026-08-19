-- ============================================================================
-- Page Views do funil despencaram para 37 nos dias 18-19/08, com 25 checkouts
-- e 31 vendas — mais venda que visita, o que é impossível.
--
-- Causa: duas LPs novas no ar desde 17/08 chegam com DUAS grafias que não se
-- encontram. O GA4 traz o caminho da URL; o checkout traz o nome da página na
-- UTM. Sem tradução, a vw_pagina_resumo cria duas linhas para a mesma página:
--
--   /workshop-estrategista-patrimonial-lp04-h1-v5-wep    86 views   0 ck   0 vd
--    workshop estrategista patrimonial | lp04-h1-v5 wep   0 views  14 ck  10 vd
--   /workshop-estrategista-patrimonial-lp02-h1-v2-wep    54 views   0 ck   0 vd
--    workshop estrategista patrimonial | lp02-h1-v2 wep   0 views  10 ck   9 vd
--
-- O filtro de "página de venda" do funil (sql/64) então descarta a linha das
-- views — slug sem "vend"/"-pv-" e sem conversão — e mantém a dos checkouts,
-- que tem zero view. Daí 37 em vez de 177.
--
-- Sonda (datas batem exatamente nos dois lados, sem concorrente):
--   lp02-h1-v2:  ck 2/8/2 em 17,18,19   |  views 32/45/9  em 17,18,19
--   lp04-h1-v5:  ck 1/12/2 em 17,18,19  |  views 22/69/17 em 17,18,19
--
-- QUARTO formato de nomenclatura até agora, e o "wep" mudou de posição:
--   1º  'imersão estrategista patrimonial l pv l h2v4'         (separador " l ")
--   2º  'workshop estrategista patrimonial | wep pv h5-v1'     ("| wep pv ...")
--   3º  'workshop estrategista patrimonial | lp02-h1-v1 wep'   -> /...-wep-lp02-h1-v1
--   4º  'workshop estrategista patrimonial | lp02-h1-v2 wep'   -> /...-lp02-h1-v2-wep
--
-- Por isso, além das duas linhas no CASE, entra um FALLBACK mecânico: quando o
-- nome tem "|" e o CASE não reconhece, deriva o slug trocando "|" e espaços por
-- hífen. Isso reproduz exatamente o padrão do 4º formato, que é o vigente — a
-- próxima LP nomeada assim casa sozinha, sem esperar alguém notar o furo.
--
-- O fallback não piora nenhum caso: hoje o "else p" devolve o nome cru, que já
-- vira linha órfã com zero view. Se a derivação não existir no GA4, continua
-- órfã, só que com outro rótulo. Ele age apenas em texto com "|", então os
-- formatos 1 e 3 (mapeados no CASE, que vem antes) seguem intactos.
--
-- Efeito esperado no funil de 18-19/08: Page Views 37 -> 177.
-- Com isso a Conversão página cai de 83,78% para ~17,5% e o CPLV de R$ 44,47
-- para ~R$ 9,34 — os números que estavam inflados pelo denominador quebrado.
-- ============================================================================
create or replace function mkt_wep.norm_pagina_venda(p text)
returns text
language sql
immutable
as $$
  select case
    when p = 'imersão estrategista patrimonial l pv l h1v1'
      then '/imersao-estrategista-patrimonial-wep-vend-h1-v1'
    when p = 'imersão estrategista patrimonial l pv l h2v1'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2v1'
    when p = 'imersão estrategista patrimonial l pv l h3v1'
      then '/imersao-estrategista-patrimonial-l-pv-l-h3v1'
    when p = 'imersão estrategista patrimonial l pv l h2v4'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2v4'
    when p = 'imersão estrategista patrimonial l pv l h3-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h3-v1'
    when p = 'imersão estrategista patrimonial l pv l h1v4'
      then '/imersao-estrategista-patrimonial-wep-pv-h1-v4'
    when p = 'imersão estrategista patrimonial l pv l h1-v4'
      then '/imersao-estrategista-patrimonial-wep-pv-h1-v4'
    when p = 'imersao-estrategista-patrimonial-l-pv-l-h2-v2'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2-v2'
    when p = 'imersão estrategista patrimonial l pv l h2v2'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2-v2'
    when p = 'workshop estrategista patrimonial | wep pv h5-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h5-v1'
    when p = 'workshop estrategista patrimonial | wep pv h6-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h6-v1'
    when p = 'workshop estrategista patrimonial | wep pv h7-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h7-v1'
    when p = 'imersão estrategista patrimonial l pv l h8-v3l1'
      then '/imersao-estrategista-patrimonial-wep-pv-h8-v3l1'
    when p = 'imersão estrategista patrimonial l pv l h8-v3l2'
      then '/imersao-estrategista-patrimonial-wep-pv-h8-v3l2'
    -- 3º formato: o "wep" vinha ANTES do código da LP no slug
    when p = 'workshop estrategista patrimonial | lp02-h1-v1 wep'
      then '/workshop-estrategista-patrimonial-wep-lp02-h1-v1'
    when p = 'workshop estrategista patrimonial | lp04-h1-v4 wep'
      then '/workshop-estrategista-patrimonial-wep-lp04-h1-v4'
    -- ── novas (4º formato, no ar desde 17/08) ───────────────────────────────
    when p = 'workshop estrategista patrimonial | lp02-h1-v2 wep'
      then '/workshop-estrategista-patrimonial-lp02-h1-v2-wep'
    when p = 'workshop estrategista patrimonial | lp04-h1-v5 wep'
      then '/workshop-estrategista-patrimonial-lp04-h1-v5-wep'
    -- ── fallback do 4º formato: deriva o slug do próprio nome ────────────────
    -- 'workshop estrategista patrimonial | lp05-h1-v1 wep'
    --   -> '/workshop-estrategista-patrimonial-lp05-h1-v1-wep'
    when p like '%|%'
      then '/' || regexp_replace(
             regexp_replace(lower(btrim(p)), '[|[:space:]]+', '-', 'g'),
             '-{2,}', '-', 'g'
           )
    else p
  end;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) As duas páginas com views E conversão na MESMA linha
--     (esperado: lp02-h1-v2 com 86 views/12 ck; lp04-h1-v5 com 108/15):
select pagina,
       sum(page_views) as views,
       sum(checkouts)  as checkouts,
       sum(vendas)     as vendas
  from mkt_wep.vw_pagina_resumo
 where pagina in (
   '/workshop-estrategista-patrimonial-lp02-h1-v2-wep',
   '/workshop-estrategista-patrimonial-lp04-h1-v5-wep'
 )
 group by pagina
 order by pagina;

-- (b) O funil de 18-19 volta a ter Page Views > Vendas (esperado: 177):
select etapa, valor
  from mkt_wep.fn_funil(null, '2026-08-18', '2026-08-19', null, null, true)
 order by ordem;

-- (c) Nenhuma órfã nova (esperado: só a "(sem página)" já conhecida):
select distinct pagina
  from mkt_wep.vw_pagina_resumo
 where pagina not like '/%';

-- (d) O CASE continua vencendo o fallback nos formatos antigos — estes DEVEM
--     apontar para o slug com "wep" no meio, não para a derivação mecânica:
select p as nome_no_checkout, mkt_wep.norm_pagina_venda(p) as slug
  from unnest(array[
    'workshop estrategista patrimonial | lp02-h1-v1 wep',  -- /...-wep-lp02-h1-v1
    'workshop estrategista patrimonial | lp04-h1-v4 wep',  -- /...-wep-lp04-h1-v4
    'workshop estrategista patrimonial | wep pv h5-v1'     -- /imersao-...-wep-pv-h5-v1
  ]) as p;
