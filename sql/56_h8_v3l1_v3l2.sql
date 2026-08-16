-- ============================================================================
-- H8-V3L1 e H8-V3L2: duas variantes novas de página de vendas.
--
-- Estado antes desta migração (verificado por sonda):
--   - GA4 já registra as duas páginas em vw_paginas_diario (o slug tem "wep",
--     então não precisa de exceção lá).
--   - vw_checkouts tem 1 checkout em cada, com o nome de produto vindo no
--     formato antigo (separador " l ", igual às H1/H2/H3 — e NÃO no formato
--     " | wep pv " que as H5/H6/H7 usaram no sql/51).
--   - vw_vendas ainda não tem venda nenhuma nessas duas (nada a recuperar
--     retroativamente; o mapeamento passa a valer da primeira venda em diante).
--
-- Só o CASE precisa mudar. Nada de mexer em vw_paginas_diario.
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
    when 'imersao-estrategista-patrimonial-l-pv-l-h2-v2'
      then '/imersao-estrategista-patrimonial-l-pv-l-h2-v2'
    when 'workshop estrategista patrimonial | wep pv h5-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h5-v1'
    when 'workshop estrategista patrimonial | wep pv h6-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h6-v1'
    when 'workshop estrategista patrimonial | wep pv h7-v1'
      then '/imersao-estrategista-patrimonial-wep-pv-h7-v1'
    -- ── novas (H8) ───────────────────────────────────────────────────────────
    when 'imersão estrategista patrimonial l pv l h8-v3l1'
      then '/imersao-estrategista-patrimonial-wep-pv-h8-v3l1'
    when 'imersão estrategista patrimonial l pv l h8-v3l2'
      then '/imersao-estrategista-patrimonial-wep-pv-h8-v3l2'
    else p
  end;
$$;

-- ── Conferência ─────────────────────────────────────────────────────────────
-- As duas linhas devem aparecer com o caminho começando em "/" (mapeado),
-- e os page views do GA4 correlacionados com os checkouts.
select pagina, page_views, checkouts, vendas
  from mkt_wep.vw_pagina_resumo
 where pagina ilike '%h8-v3%'
 order by pagina;
