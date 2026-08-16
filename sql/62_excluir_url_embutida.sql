-- ============================================================================
-- Remove do GA4 os caminhos com uma URL inteira colada dentro do path — sobra
-- de rastreamento, não é página real. Ex. achado em 14/08 (1 view):
--   /imersao-estrategista-patrimonial-wep-pv-h5-v1https://p.quartavia.com.br/
--   imersao-estrategista-patrimonial-wep-pv-h8-v1
--
-- Em vez de listar esse caso (como o sql/52 fez com os dois de UTM colada),
-- vai uma regra para a classe inteira: descarta quando existe "http:" ou
-- "https:" precedido de qualquer caractere.
--
-- Por que ".+" antes: um caminho que COMEÇA com https:// é legítimo — o
-- norm_pagina() já tira o protocolo e o host. O defeito é o protocolo aparecer
-- no MEIO (ou depois de uma barra), sinal de dois endereços concatenados.
--
-- Cobre as 4 linhas existentes hoje: 1 do WEP e 3 de "alavanca-patrimonial"
-- (essas já ficavam de fora pelo filtro de "wep", mas a regra as impede de
-- entrar caso o filtro mude).
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
  -- novo: URL colada dentro do caminho (protocolo no meio, não no início)
  and caminho_da_pagina !~* '.+https?:'
  and (source is null or lower(source) not in ('test', 'codex_browser_qa'))
group by data, mkt_wep.norm_pagina(caminho_da_pagina);

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Nenhuma página com URL embutida (esperado: 0 linhas):
select pagina, sum(page_views) as views
  from mkt_wep.vw_paginas_diario
 where pagina ~* '.+https?:'
 group by pagina;

-- (b) A tabela de vendas em 14-16/08 deve perder só 1 view do total
--     (de 389 para 388) e manter 14 checkouts e 5 vendas:
select sum(page_views) as views, sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.vw_pagina_resumo
 where data between '2026-08-14' and '2026-08-16';
