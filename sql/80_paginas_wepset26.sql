-- ============================================================================
-- As LPs do WEPSET26 apareciam DUAS VEZES na tabela: uma linha com as views e
-- zero conversão, outra com a conversão e zero view.
--
--   /workshop-estrategista-patrimonial-lp01-h1-v1-wepset26   18 views  0 ck
--   /workshop-estrategista-patrimonial-lp01-h1-wep            0 views  1 ck
--
-- ⚠️ A CAUSA ESTÁ NA ORIGEM, NÃO NO PAINEL. A UTM de página configurada nas LPs
-- novas ficou com o sufixo da edição ANTERIOR:
--
--   checkout grava : "Workshop Estrategista Patrimonial | lp01-h1 Wep"
--   URL de verdade : /workshop-estrategista-patrimonial-lp01-h1-v1-wepset26
--
-- Duas diferenças: o sufixo é "Wep" e não "wepset26", e no lp01 falta o "-v1".
-- O fallback do sql/74 deriva o slug do nome, então fabricou
-- "/workshop-...-lp01-h1-wep" — um caminho que NÃO EXISTE no GA4 (conferido:
-- zero views em toda a série histórica). Não é a página errada, é uma página
-- inexistente.
--
-- Sonda antes de mapear: essas duas grafias aparecem em 5 checkouts e 2 vendas,
-- TODOS com tag=WEPSET26 e a partir de 09/09. Nenhum uso em edição anterior,
-- então o mapa não reescreve o passado de ninguém.
--
-- ⚠️ ESTE MAPA TEM PRAZO DE VALIDADE. Ele diz "lp01-h1 wep => página de
-- setembro". Se a UTM não for corrigida e a edição de OUTUBRO gravar o mesmo
-- texto, as vendas de outubro serão atribuídas à LP de setembro — e aí o painel
-- mente com convicção, que é pior do que a linha duplicada de hoje. O conserto
-- de verdade é na origem:
--
--   AÇÃO NA LP: corrigir o parâmetro de página do checkout para bater com a URL
--   "Workshop Estrategista Patrimonial | lp01-h1-v1 wepset26"
--   "Workshop Estrategista Patrimonial | lp02-h1 wepset26"
--
-- Feito isso, o fallback do sql/74 casa sozinho e estas duas linhas viram só
-- cobertura do histórico de setembro.
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
    -- 4º formato (WEPAGO26, ago/26)
    when p = 'workshop estrategista patrimonial | lp02-h1-v2 wep'
      then '/workshop-estrategista-patrimonial-lp02-h1-v2-wep'
    when p = 'workshop estrategista patrimonial | lp04-h1-v5 wep'
      then '/workshop-estrategista-patrimonial-lp04-h1-v5-wep'
    -- ── WEPSET26: UTM ficou com o sufixo da edição anterior ("Wep") ─────────
    -- Enquanto a LP não for corrigida, é isto que chega no checkout. Ver o
    -- aviso de prazo de validade no cabeçalho deste arquivo.
    when p = 'workshop estrategista patrimonial | lp01-h1 wep'
      then '/workshop-estrategista-patrimonial-lp01-h1-v1-wepset26'
    when p = 'workshop estrategista patrimonial | lp02-h1 wep'
      then '/workshop-estrategista-patrimonial-lp02-h1-wepset26'
    -- ── fallback do formato vigente: deriva o slug do próprio nome ──────────
    -- 'workshop estrategista patrimonial | lp05-h1-v1 wepset26'
    --   -> '/workshop-estrategista-patrimonial-lp05-h1-v1-wepset26'
    when p like '%|%'
      then '/' || regexp_replace(
             regexp_replace(lower(btrim(p)), '[|[:space:]]+', '-', 'g'),
             '-{2,}', '-', 'g'
           )
    else p
  end;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) O QUE IMPORTA: as LPs do SET26 numa linha só, com views E conversão
--     juntas. As linhas "-lp01-h1-wep" / "-lp02-h1-wep" têm que sumir:
select pagina,
       sum(page_views) as views,
       sum(checkouts)  as checkouts,
       sum(vendas)     as vendas
  from mkt_wep.vw_pagina_resumo
 where data >= '2026-09-10'
 group by pagina
 order by views desc, checkouts desc;

-- (b) Nenhuma página fabricada sobrou (esperado: 0 linhas):
select pagina, sum(checkouts) as ck, sum(vendas) as vd
  from mkt_wep.vw_pagina_resumo
 where pagina in (
   '/workshop-estrategista-patrimonial-lp01-h1-wep',
   '/workshop-estrategista-patrimonial-lp02-h1-wep'
 )
 group by pagina;

-- (c) O total de checkouts e vendas NÃO muda — o mapa move conversão de linha,
--     não cria nem destrói. Compare com o valor de antes de rodar:
select sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.vw_pagina_resumo;

-- (d) Os formatos antigos continuam intactos — o CASE vem antes do fallback
--     (esperado: os slugs com "wep" no meio, não a derivação mecânica):
select p as nome_no_checkout, mkt_wep.norm_pagina_venda(p) as slug
  from unnest(array[
    'workshop estrategista patrimonial | lp02-h1-v1 wep',
    'workshop estrategista patrimonial | lp04-h1-v4 wep',
    'workshop estrategista patrimonial | wep pv h5-v1',
    'workshop estrategista patrimonial | lp01-h1 wep',
    'workshop estrategista patrimonial | lp02-h1 wep',
    'workshop estrategista patrimonial | lp01-h1-v1 wepset26'
  ]) as p;
