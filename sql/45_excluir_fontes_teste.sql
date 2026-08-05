-- ============================================================================
-- Remove fontes de tráfego de teste/QA (não são visitante real) — na origem,
-- então cai de todo o dashboard de uma vez: funil (Page Views/CPLV/Conversão
-- Página), tabela "Desempenho página de vendas", série por dia. Tudo isso
-- lê mkt_wep.vw_paginas_diario, então basta filtrar aqui.
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
  and (source is null or lower(source) not in ('test', 'codex_browser_qa'))
group by data, mkt_wep.norm_pagina(caminho_da_pagina);
