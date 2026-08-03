-- ============================================================================
-- H2V1: mesmo bug do H3V1 — página criada SEM "wep" no slug.
-- URL real (GA4, 227 page views desde 29/07): /imersao-estrategista-patrimonial-l-pv-l-h2v1/
-- O mapeamento anterior (sql/35) apontava errado pra
-- /imersao-estrategista-patrimonial-wep-vend-h2, que é outra URL (praticamente
-- sem tráfego real — só 1 view "solta").
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
    or caminho_da_pagina ilike '%imersao-estrategista-patrimonial-l-pv-l-h3v1%'
    or caminho_da_pagina ilike '%imersao-estrategista-patrimonial-l-pv-l-h2v1%'
  )
  and caminho_da_pagina not ilike '%tkp%'
group by data, mkt_wep.norm_pagina(caminho_da_pagina);

create or replace function mkt_wep.norm_pagina_venda(p text)
returns text
language sql
immutable
as $$
  select case p
    when 'imersão estrategista patrimonial l pv l h1v1'
      then '/imersao-estrategista-patrimonial-wep-vend-h1-v1'
    when 'imersão estrategista patrimonial l pv l h2v1'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2v1'
    when 'imersão estrategista patrimonial l pv l h3v1'
      then '/imersao-estrategista-patrimonial-l-pv-l-h3v1'
    else p
  end;
$$;
