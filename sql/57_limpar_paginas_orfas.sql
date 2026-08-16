-- ============================================================================
-- Limpa as 3 páginas órfãs que sobraram na vw_pagina_resumo (linhas cujo texto
-- não começa com "/" — ou seja, nome de produto que nunca casou com uma página).
--
--   1. 'imersão estrategista patrimonial l pv l h1-v4'  (1 checkout)
--      -> mesma variante do 'h1v4' já mapeado, só escrita com hífen.
--         Confirmado pelo Igor: soma junto.
--
--   2. 'imersão estrategista patrimonial l pv l h2v2'   (2 checkouts, 06/08)
--      -> ver nota de ambiguidade abaixo.
--
--   3. 'forms_nativo'                                   (1 venda, 0 checkout)
--      -> não é página de vendas, é origem de lead. Vinha parar aqui pelo
--         `else p` do CASE. Passa pra lista de exclusão da view.
--         ATENÇÃO: isso tira 1 venda do total da tabela "Desempenho página de
--         vendas" (ela continua nos cards/funil, que não passam por essa view).
-- ============================================================================

-- ── 1) View: exclui forms_nativo ────────────────────────────────────────────
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
  coalesce(g.pagina, c.pagina, v.pagina) as pagina,
  coalesce(g.data, c.data, v.data)       as data,
  coalesce(g.page_views, 0)              as page_views,
  coalesce(c.checkouts, 0)               as checkouts,
  coalesce(v.vendas, 0)                  as vendas
from ga4 g
full join cks c on c.pagina = g.pagina and c.data = g.data
full join vds v on v.pagina = coalesce(g.pagina, c.pagina)
              and v.data   = coalesce(g.data, c.data);

-- ── 2) CASE: h1-v4 e h2v2 ───────────────────────────────────────────────────
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
    -- grafia alternativa da MESMA variante (com hífen) — soma junto:
    when 'imersão estrategista patrimonial l pv l h1-v4'
      then '/imersao-estrategista-patrimonial-wep-pv-h1-v4'
    when 'imersao-estrategista-patrimonial-l-pv-l-h2-v2'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2-v2'
    -- grafia alternativa do h2-v2 (acentuada, sem hífen). Escolhi a página
    -- "-l-pv-l-" porque o nome do produto usa o mesmo padrão " l pv l " e a
    -- outra grafia desse produto já aponta pra ela. Se descobrir que os 2
    -- checkouts de 06/08 vieram da "-wep-pv-", é só trocar o then abaixo por
    -- '/imersao-estrategista-patrimonial-wep-pv-h2-v2'.
    when 'imersão estrategista patrimonial l pv l h2v2'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2-v2'
    when 'workshop estrategista patrimonial | wep pv h5-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h5-v1'
    when 'workshop estrategista patrimonial | wep pv h6-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h6-v1'
    when 'workshop estrategista patrimonial | wep pv h7-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h7-v1'
    when 'imersão estrategista patrimonial l pv l h8-v3l1'
      then '/imersao-estrategista-patrimonial-wep-pv-h8-v3l1'
    when 'imersão estrategista patrimonial l pv l h8-v3l2'
      then '/imersao-estrategista-patrimonial-wep-pv-h8-v3l2'
    else p
  end;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- Deve voltar VAZIO (nenhuma página órfã sobrando):
select distinct pagina
  from mkt_wep.vw_pagina_resumo
 where pagina not like '/%';

-- As duas que receberam os órfãos (h1-v4 deve ter 1 checkout a mais,
-- h2-v2 deve ter 9 checkouts no total = 7 + 2):
select pagina, sum(page_views) as views, sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.vw_pagina_resumo
 where pagina in (
   '/imersao-estrategista-patrimonial-wep-pv-h1-v4',
   '/imersao-estrategista-patrimonial-l-pv-l-h2-v2'
 )
 group by pagina;
