-- ============================================================================
-- H2V4: correção. A URL real é /imersao-estrategista-patrimonial-l-pv-l-h2v4
-- (78 views reais, fontes legítimas) — mesmo bug do H2V1/H3V1 (slug sem "wep").
-- A que eu tinha mapeado antes (wep-pv-h2-v4, sql/41) tinha só 3 views soltas,
-- não é a landing page de verdade.
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
    or caminho_da_pagina ilike '%imersao-estrategista-patrimonial-l-pv-l-h2v4%'
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
    when 'imersão estrategista patrimonial l pv l h2v4'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2v4'
    else p
  end;
$$;
