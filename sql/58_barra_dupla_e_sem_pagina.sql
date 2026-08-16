-- ============================================================================
-- Dois acertos achados na auditoria de vinculação (checkout x page view x venda):
--
--   1. BARRA DUPLA — o GA4 registrou 3 páginas como "//imersao-..." e o
--      norm_pagina() não colapsa barras repetidas (ele só tira protocolo,
--      query e barra final). Resultado: a mesma página vira duas linhas na
--      tabela. Hoje o desvio é de 1 view em cada, mas é silencioso: se uma
--      URL com "//" pegar tráfego de verdade, ela rouba views da página certa
--      sem ninguém perceber.
--
--   2. VENDA SEM PÁGINA — 5 vendas de 30/07 (R$ 17 cada) vieram sem UTM de
--      página, então caem numa linha de nome vazio na tabela. Não há o que
--      mapear: a origem não foi gravada. Passa a exibir "(sem página)" para
--      a linha ser legível, mantendo as vendas visíveis e o total da tabela
--      fechando com o funil.
--
-- Contexto da vinculação depois destes acertos: 92 de 92 checkouts vinculados,
-- e 59 das 60 vendas válidas na tabela (a que falta é a forms_nativo, excluída
-- de propósito no sql/57 por não ser página).
-- ============================================================================

-- ── 1) norm_pagina: colapsa barras repetidas ────────────────────────────────
-- Mesma definição do sql/29, com um regexp_replace a mais no fim.
-- Idempotente: rodar de novo não muda nada em quem já está normalizado.
create or replace function mkt_wep.norm_pagina(p text)
returns text
language sql
immutable
as $$
  select regexp_replace(
    replace(
      rtrim(
        regexp_replace(
          regexp_replace(lower(coalesce(p, '')), '^https?://[^/]+', ''),
          '[?#].*$', ''
        ),
        '/'
      ),
      'imersao-engenheiro-patrimonial', 'imersao-estrategista-patrimonial'
    ),
    '/{2,}', '/', 'g'   -- "//pagina" e "/a//b" viram "/pagina" e "/a/b"
  );
$$;

-- ── 2) vw_pagina_resumo: rótulo para a linha sem página ─────────────────────
create or replace view mkt_wep.vw_pagina_resumo as
with excluidas as (
  select unnest(array[
    '/imersao-estrategista-patrimonial-wep-vend-h1-v2',
    '/imersao-estrategista-patrimonial-wep-vend-h2',
    'forms_nativo'
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
  -- nullif pega tanto '' quanto o resultado de uma UTM em branco
  coalesce(nullif(coalesce(g.pagina, c.pagina, v.pagina), ''), '(sem página)') as pagina,
  coalesce(g.data, c.data, v.data)       as data,
  coalesce(g.page_views, 0)              as page_views,
  coalesce(c.checkouts, 0)               as checkouts,
  coalesce(v.vendas, 0)                  as vendas
from ga4 g
full join cks c on c.pagina = g.pagina and c.data = g.data
full join vds v on v.pagina = coalesce(g.pagina, c.pagina)
              and v.data   = coalesce(g.data, c.data);

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Nenhuma página com barra dupla deve sobrar (esperado: 0 linhas):
select pagina, sum(page_views) as views
  from mkt_wep.vw_pagina_resumo
 where pagina like '//%'
 group by pagina;

-- (b) As 3 páginas afetadas devem ter ganho 1 view cada
--     (271->272, 461->462, 331->332):
select pagina, sum(page_views) as views, sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.vw_pagina_resumo
 where pagina in (
   '/imersao-estrategista-patrimonial-l-pv-l-h2v1',
   '/imersao-estrategista-patrimonial-l-pv-l-h2v4',
   '/imersao-estrategista-patrimonial-wep-pv-h3-v1'
 )
 group by pagina
 order by pagina;

-- (c) A linha sem página agora tem nome (esperado: 5 vendas):
select pagina, sum(page_views) as views, sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.vw_pagina_resumo
 where pagina = '(sem página)'
 group by pagina;

-- (d) Total da tabela deve continuar 92 checkouts e 59 vendas:
select sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.vw_pagina_resumo;
