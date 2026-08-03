-- ============================================================================
-- REMENDO: cruzar checkout/venda com page views quando o utm_pagina gravado
-- não é a URL da página, e sim o nome do produto/oferta no Hotmart.
--
-- Achado (jul/2026): 100% dos checkouts recentes e boa parte das vendas do
-- período Padrão têm utm_pagina = nome do produto Hotmart (ex.: "Imersão
-- Estrategista Patrimonial l PV l H1V1"), não a URL (ex.:
-- "/imersao-estrategista-patrimonial-wep-vend-h1-v1"). Como vw_pagina_resumo
-- junta GA4 + checkout + venda pela página normalizada, esses valores nunca
-- batiam — cada um virava uma linha solta, com zero do que faltou.
--
-- REMENDO TEMPORÁRIO: mapeia os nomes conhecidos pra URL certa. A correção
-- definitiva é na origem (o que grava utm_pagina no checkout — Make? webhook
-- Hotmart direto? — ainda não identificado) mandar a URL real, não o nome do
-- produto. Enquanto isso, cada variação nova de página vai continuar caindo
-- fora daqui até alguém adicionar a linha correspondente neste CASE.
--
-- H3V1 ainda SEM url confirmada (aguardando resposta) — fica de fora do mapa
-- por enquanto, passa direto sem tradução (linha solta, como já era).
-- ============================================================================

create or replace function mkt_wep.norm_pagina_venda(p text)
returns text
language sql
immutable
as $$
  -- p já vem normalizado (saída de mkt_wep.norm_pagina, aplicada em
  -- vw_checkouts/vw_vendas) — aqui só troca os nomes de produto conhecidos.
  select case p
    when 'imersão estrategista patrimonial l pv l h1v1'
      then '/imersao-estrategista-patrimonial-wep-vend-h1-v1'
    when 'imersão estrategista patrimonial l pv l h2v1'
      then '/imersao-estrategista-patrimonial-wep-vend-h2'
    else p
  end;
$$;

create or replace view mkt_wep.vw_pagina_resumo as
with ga4 as (
  select pagina, data, sum(page_views) as page_views
  from mkt_wep.vw_paginas_diario
  group by pagina, data
),
cks as (
  select mkt_wep.norm_pagina_venda(pagina) as pagina, data, count(*) as checkouts
  from mkt_wep.vw_checkouts
  group by mkt_wep.norm_pagina_venda(pagina), data
),
vds as (
  select mkt_wep.norm_pagina_venda(pagina) as pagina, data,
         count(*) filter (where venda_valida) as vendas
  from mkt_wep.vw_vendas
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
