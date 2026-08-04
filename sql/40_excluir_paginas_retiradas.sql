-- ============================================================================
-- EXCLUIR PÁGINAS RETIRADAS DO DASH (Padrão) — não aparecer em NADA:
-- tabela, card "Conversão Página", funil (Page Views/CPLV/Conversão Página),
-- sem afetar o Meteórico.
--
-- Onde isso importa: no Padrão, Page Views do funil + CPLV + card Conversão
-- Página são recalculados no FRONT a partir de data.pages (mesma fonte da
-- tabela "Desempenho página de vendas") — então excluir aqui, em
-- vw_pagina_resumo (única consumidora: fn_paginas), já resolve tudo de uma
-- vez. fn_funil/fn_serie_diaria leem vw_paginas_diario DIRETO (não esta
-- view) — por isso o Meteórico, que usa o Page Views bruto do funil (sem
-- override), fica intocado.
--
-- Páginas retiradas (pedido do Igor, 03/08/2026):
--   /imersao-estrategista-patrimonial-wep-vend-h1-v2  (duplicata órfã, ~0 tráfego)
--   /imersao-estrategista-patrimonial-wep-vend-h2     (duplicata órfã, ~0 tráfego — a de verdade é l-pv-l-h2v1)
--   /imersao-estrategista-patrimonial-wep-pv-h1-v4    (variante de teste retirada)
-- ============================================================================

create or replace view mkt_wep.vw_pagina_resumo as
with excluidas as (
  select unnest(array[
    '/imersao-estrategista-patrimonial-wep-vend-h1-v2',
    '/imersao-estrategista-patrimonial-wep-vend-h2',
    '/imersao-estrategista-patrimonial-wep-pv-h1-v4'
  ]) as pagina
),
ga4 as (
  select pagina, data, sum(page_views) as page_views
  from mkt_wep.vw_paginas_diario
  where pagina not in (select pagina from excluidas)
  group by pagina, data
),
cks as (
  select mkt_wep.norm_pagina_venda(pagina) as pagina, data, count(*) as checkouts
  from mkt_wep.vw_checkouts
  where pagina not ilike '%popup%'
    and mkt_wep.norm_pagina_venda(pagina) not in (select pagina from excluidas)
  group by mkt_wep.norm_pagina_venda(pagina), data
),
vds as (
  select mkt_wep.norm_pagina_venda(pagina) as pagina, data,
         count(*) filter (where venda_valida) as vendas
  from mkt_wep.vw_vendas
  where pagina not ilike '%popup%'
    and mkt_wep.norm_pagina_venda(pagina) not in (select pagina from excluidas)
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
