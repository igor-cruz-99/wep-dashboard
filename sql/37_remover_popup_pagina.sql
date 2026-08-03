-- ============================================================================
-- Remove "WEP – Popup Padrão – VENDAS" da tabela de desempenho por página.
-- Não é uma página (não tem GA4, não tem URL) — é um checkout que entra
-- direto por popup/WhatsApp. Continua contando nos totais gerais de
-- checkout/venda do dashboard (esses vêm de vw_checkouts/vw_vendas direto,
-- não desta view) — só sai da tabela "Desempenho página de vendas".
-- ============================================================================
create or replace view mkt_wep.vw_pagina_resumo as
with ga4 as (
  select pagina, data, sum(page_views) as page_views
  from mkt_wep.vw_paginas_diario
  group by pagina, data
),
cks as (
  select mkt_wep.norm_pagina_venda(pagina) as pagina, data, count(*) as checkouts
  from mkt_wep.vw_checkouts
  where pagina not ilike '%popup%'
  group by mkt_wep.norm_pagina_venda(pagina), data
),
vds as (
  select mkt_wep.norm_pagina_venda(pagina) as pagina, data,
         count(*) filter (where venda_valida) as vendas
  from mkt_wep.vw_vendas
  where pagina not ilike '%popup%'
  group by mkt_wep.norm_pagina_venda(pagina), data
)
select
  coalesce(g.pagina, c.pagina, v.pagina) as pagina,
  coalesce(g.data, c.data, v.data)       as data,
  coalesce(g.page_views, 0)              as page_views,
  coalesce(c.checkouts, 0)               as checkouts,
  coalesce(v.vendas, 0)                  as vendas
from ga4 g
full join cks c on c.pagina = g.pagina and c.data = g.data
full join vds v on v.pagina = coalesce(g.pagina, c.pagina)
              and v.data   = coalesce(g.data, c.data);
