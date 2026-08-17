-- ============================================================================
-- Page views não batiam com o GA4: a vw_paginas_diario só aceita caminho com
-- "wep" no slug, e várias páginas do produto não têm. Em agosto/2026 isso
-- deixava 327 views de fora.
--
-- Levantamento (radical "estrateg", pega qualquer grafia): 23.582 views no GA4,
-- das quais 19.339 (46 páginas) ficavam fora por não ter "wep" no caminho.
-- Destas, 13 têm tráfego em agosto e foram confirmadas pelo Igor como do
-- lançamento atual — são as listadas abaixo.
--
-- Fica FORA de propósito:
--   - páginas "tkp" (obrigado / pós-compra) — exclusão do sql/17, confirmada;
--   - 31 páginas de lançamentos anteriores, sem nenhum tráfego em agosto;
--   - 2 com grafia colada ("workshopestrategistapatrimonial-*-nova-profissao"),
--     8 views no total, todas de dez/25 e jan/26.
--
-- ATENÇÃO ao efeito no histórico: 4 das 13 são páginas antigas que ainda pingam
-- visita ocasional, e elas trazem o passado junto — lp04-h1-v3 sozinha tem 8.783
-- views desde janeiro. Por isso o total geral sobe muito mais que agosto:
--   views totais : 5.994 -> 17.799  (+11.805)
--   views agosto : 3.414 ->  3.741  (+327)
--   páginas      :    56 ->     69
-- Isso é esperado e foi decidido conscientemente. Se um dia incomodar no
-- acumulado, as candidatas a sair são lp04-h1-v3, lp04-h1-v5-ht, lp02-h1 e
-- lp01-h1 (as quatro de prefixo "workshop-").
--
-- Por que comparação exata (= any(array)) e não ilike '%...%': vários desses
-- slugs são prefixo um do outro. '%...-l-pv-l-h2%' pegaria h2v4, h2v5, h2-v2
-- e mais um punhado — a comparação sobre norm_pagina() evita esse alastramento.
-- ============================================================================
create or replace view mkt_wep.vw_paginas_diario as
select
  data,
  mkt_wep.norm_pagina(caminho_da_pagina) as pagina,
  sum(visualizacoes)   as page_views,
  sum(usuarios_unicos) as usuarios_unicos
from core.paginas_ga4
where (
    caminho_da_pagina ilike '%wep%'
    -- exceções antigas (sql/52), mantidas como estavam
    or caminho_da_pagina ilike '%imersao-estrategista-patrimonial-l-pv-l-h3v1%'
    or caminho_da_pagina ilike '%imersao-estrategista-patrimonial-l-pv-l-h2v1%'
    or caminho_da_pagina ilike '%imersao-estrategista-patrimonial-l-pv-l-h2v4%'
    or caminho_da_pagina ilike '%imersao-estrategista-patrimonial-l-pv-l-h2-v2%'
    -- páginas do produto sem "wep" no slug, confirmadas uma a uma
    or mkt_wep.norm_pagina(caminho_da_pagina) = any (array[
      '/imersao-estrategista-patrimonial-lp01-h1',
      '/imersao-estrategista-patrimonial-ingresso-lp01-h1',
      '/imersao-estrategista-patrimonial-ingresso-lp01-h1-v2',
      '/imersao-estrategista-patrimonial-l-pv-l-h2',
      '/imersao-estrategista-patrimonial-l-pv-l-h2v5',
      '/imersao-estrategista-patrimonial-l-pv-l-h6-v1',
      '/imersao-estrategista-patrimonial-lp02-h1',
      '/imersao-estrategista-patrimonial-lp07-h1',
      '/imersao-estrategista-patrimonial-pl01-h1-v1',
      '/workshop-estrategista-patrimonial-lp01-h1',
      '/workshop-estrategista-patrimonial-lp02-h1',
      '/workshop-estrategista-patrimonial-lp04-h1-v3',
      '/workshop-estrategista-patrimonial-lp04-h1-v5-ht'
    ])
  )
  and caminho_da_pagina not ilike '%tkp%'
  and caminho_da_pagina not ilike '%h2v4&utm_source=rec_email%'
  and caminho_da_pagina not ilike '%h2v40&utm_source=grupos_antigos%'
  and caminho_da_pagina !~* '.+https?:'
  and (source is null or lower(source) not in ('test', 'codex_browser_qa'))
group by data, mkt_wep.norm_pagina(caminho_da_pagina);

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) AGOSTO: esperado 3.741 views (era 3.414):
select sum(page_views) as views_agosto
  from mkt_wep.vw_paginas_diario
 where data >= '2026-08-01';

-- (b) TOTAL: esperado 17.799 views e 69 páginas (era 5.994 e 56):
select sum(page_views) as views_total, count(distinct pagina) as paginas
  from mkt_wep.vw_paginas_diario;

-- (c) As 13 devem aparecer agora (esperado: 13 linhas):
select pagina, sum(page_views) as views
  from mkt_wep.vw_paginas_diario
 where pagina = any (array[
   '/imersao-estrategista-patrimonial-lp01-h1',
   '/imersao-estrategista-patrimonial-ingresso-lp01-h1',
   '/imersao-estrategista-patrimonial-ingresso-lp01-h1-v2',
   '/imersao-estrategista-patrimonial-l-pv-l-h2',
   '/imersao-estrategista-patrimonial-l-pv-l-h2v5',
   '/imersao-estrategista-patrimonial-l-pv-l-h6-v1',
   '/imersao-estrategista-patrimonial-lp02-h1',
   '/imersao-estrategista-patrimonial-lp07-h1',
   '/imersao-estrategista-patrimonial-pl01-h1-v1',
   '/workshop-estrategista-patrimonial-lp01-h1',
   '/workshop-estrategista-patrimonial-lp02-h1',
   '/workshop-estrategista-patrimonial-lp04-h1-v3',
   '/workshop-estrategista-patrimonial-lp04-h1-v5-ht'
 ])
 group by pagina
 order by sum(page_views) desc;

-- (d) Nenhuma tkp entrou (esperado: 0 linhas):
select pagina from mkt_wep.vw_paginas_diario where pagina ilike '%tkp%';

-- (e) Checkouts e vendas NÃO podem mudar — só page view foi mexido
--     (esperado: 113 checkouts e 64 vendas):
select sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.vw_pagina_resumo;
