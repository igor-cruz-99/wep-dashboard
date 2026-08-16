-- ============================================================================
-- LP02-H1-V1 e LP04-H1-V4: duas páginas novas, no ar desde 14/08.
--
-- Terceiro formato de nomenclatura que aparece no checkout até agora:
--   1º  'imersão estrategista patrimonial l pv l h2v4'          (separador " l ")
--   2º  'workshop estrategista patrimonial | wep pv h5-v1'      ("| wep pv")
--   3º  'workshop estrategista patrimonial | lp02-h1-v1 wep'    ("| ... wep")  <- estas
--
-- E o slug do GA4 também mudou de prefixo: agora é "workshop-..." em vez de
-- "imersao-...". Verificado por sonda (as datas batem, sem ambiguidade):
--   'workshop estrategista patrimonial | lp02-h1-v1 wep'
--     -> /workshop-estrategista-patrimonial-wep-lp02-h1-v1  (128 views, 14-16/08)
--   'workshop estrategista patrimonial | lp04-h1-v4 wep'
--     -> /workshop-estrategista-patrimonial-wep-lp04-h1-v4  ( 95 views, 14-16/08)
--
-- Diferente das H8, aqui JÁ HÁ conversão para recuperar:
--   lp02: 9 checkouts, 3 vendas   |   lp04: 3 checkouts, 2 vendas
--
-- O slug tem "wep", então vw_paginas_diario já registra as duas — só o CASE
-- precisa mudar.
-- ============================================================================
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
    when 'imersão estrategista patrimonial l pv l h1-v4'
      then '/imersao-estrategista-patrimonial-wep-pv-h1-v4'
    when 'imersao-estrategista-patrimonial-l-pv-l-h2-v2'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2-v2'
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
    -- ── novas (LP02 / LP04) ──────────────────────────────────────────────────
    when 'workshop estrategista patrimonial | lp02-h1-v1 wep'
      then '/workshop-estrategista-patrimonial-wep-lp02-h1-v1'
    when 'workshop estrategista patrimonial | lp04-h1-v4 wep'
      then '/workshop-estrategista-patrimonial-wep-lp04-h1-v4'
    else p
  end;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) As duas páginas, agora com views + checkouts + vendas na mesma linha
--     (esperado: lp02 com 9 checkouts e 3 vendas; lp04 com 3 e 2):
select pagina,
       sum(page_views) as views,
       sum(checkouts)  as checkouts,
       sum(vendas)     as vendas
  from mkt_wep.vw_pagina_resumo
 where pagina like '/workshop-estrategista-patrimonial-wep-lp%'
 group by pagina
 order by pagina;

-- (b) Nenhuma órfã nova (esperado: 1 linha, só a "(sem página)" já conhecida):
select distinct pagina
  from mkt_wep.vw_pagina_resumo
 where pagina not like '/%';
