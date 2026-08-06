-- ============================================================================
-- H2-V2: dois problemas juntos.
-- 1) URL sem "wep" no slug (mesmo bug do H2V1/H3V1) —
--    /imersao-estrategista-patrimonial-l-pv-l-h2-v2 (12 views hoje, fontes
--    legítimas: direct/google).
-- 2) O checkout dessa variante vem num formato NOVO — já é a URL, só sem a
--    barra inicial ("imersao-estrategista-patrimonial-l-pv-l-h2-v2", sem "/").
--    norm_pagina() não adiciona a barra, então nunca batia com o lado do GA4.
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
    or caminho_da_pagina ilike '%imersao-estrategista-patrimonial-l-pv-l-h2-v2%'
  )
  and caminho_da_pagina not ilike '%tkp%'
  and (source is null or lower(source) not in ('test', 'codex_browser_qa'))
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
    when 'imersão estrategista patrimonial l pv l h3-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h3-v1'
    when 'imersão estrategista patrimonial l pv l h1v4'
      then '/imersao-estrategista-patrimonial-wep-pv-h1-v4'
    when 'imersao-estrategista-patrimonial-l-pv-l-h2-v2'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2-v2'
    else p
  end;
$$;
