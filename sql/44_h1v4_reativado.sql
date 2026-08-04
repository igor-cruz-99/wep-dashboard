-- ============================================================================
-- H1V4 reativado: /imersao-estrategista-patrimonial-wep-pv-h1-v4 foi excluída
-- em sql/40 (só 120 views, zero conversão na época) — agora tem tráfego real
-- (223+ views recentes) e checkouts (H1V4). Tira da lista de exclusão e
-- mapeia o checkout pra ela.
-- ============================================================================

-- 1) Remove da lista de exclusão (mantém só as 2 realmente mortas)
create or replace view mkt_wep.vw_pagina_resumo as
with excluidas as (
  select unnest(array[
    '/imersao-estrategista-patrimonial-wep-vend-h1-v2',
    '/imersao-estrategista-patrimonial-wep-vend-h2'
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

-- 2) Mapeia o checkout H1V4
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
    else p
  end;
$$;
