-- ============================================================================
-- Exclui páginas "tkp" (obrigado) na FONTE: vw_paginas_diario.
--
-- Antes, o filtro de tkp estava só na fn_paginas (tabela de páginas). O FUNIL
-- lê page views de vw_paginas_diario direto, então continuava contando as tkp
-- → o Page Views do funil não batia com a tabela.
--
-- Excluindo aqui, todos os consumidores ficam consistentes de uma vez:
--   • fn_funil (Page Views do funil)
--   • vw_pagina_resumo → fn_paginas (tabela de páginas)
-- A fn_paginas mantém o filtro dela também, pois além do GA4 ela exclui tkp
-- do lado dos leads (utm_pagina), que esta view não cobre.
-- ============================================================================
create or replace view mkt_wep.vw_paginas_diario as
select
  data,
  mkt_wep.norm_pagina(caminho_da_pagina) as pagina,
  sum(visualizacoes)   as page_views,
  sum(usuarios_unicos) as usuarios_unicos
from core.paginas_ga4
where caminho_da_pagina ilike '%wep%'
  and caminho_da_pagina not ilike '%tkp%'   -- fora as páginas de obrigado (thank-you)
group by data, mkt_wep.norm_pagina(caminho_da_pagina);
