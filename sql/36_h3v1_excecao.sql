-- ============================================================================
-- H3V1: página de vendas criada SEM "wep" no slug — bug de criação da página,
-- não do dashboard. URL real (GA4): /imersao-estrategista-patrimonial-l-pv-l-h3v1/
--
-- Roda depois de sql/35_norm_pagina_venda.sql (se ainda não rodou, roda ele
-- primeiro — este arquivo só complementa o CASE que ele criou).
--
-- 1) vw_paginas_diario: abre uma EXCEÇÃO pontual pra essa URL específica (não
--    afrouxa o filtro %wep% geral, que existe pra isolar o WEP dos outros
--    8 projetos que também usam core.paginas_ga4).
-- 2) norm_pagina_venda: adiciona o mapeamento do nome do produto Hotmart
--    (H3V1) pra essa URL real.
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
      then '/imersao-estrategista-patrimonial-wep-vend-h2'
    when 'imersão estrategista patrimonial l pv l h3v1'
      then '/imersao-estrategista-patrimonial-l-pv-l-h3v1'
    else p
  end;
$$;
