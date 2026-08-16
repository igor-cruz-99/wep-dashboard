-- ============================================================================
-- Remove 2 linhas do GA4 com a UTM colada no path (artefato do rastreamento,
-- "&" em vez de "?" — norm_pagina() só limpa query string a partir de "?").
-- Tráfego irrisório (2 e 1 view em 05/08), lixo de rastreamento, não página real.
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
  and caminho_da_pagina not ilike '%h2v4&utm_source=rec_email%'
  and caminho_da_pagina not ilike '%h2v40&utm_source=grupos_antigos%'
  and (source is null or lower(source) not in ('test', 'codex_browser_qa'))
group by data, mkt_wep.norm_pagina(caminho_da_pagina);
