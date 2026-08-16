-- ============================================================================
-- BUG: 1 checkout virando 50 na tela.
--
-- Sintoma (14/08/2026): "Análise de tráfego" mostrava 50 checkouts em CADA
-- linha de anúncio e 2.500 no total; o funil mostrava 50. No banco existe
-- 1 checkout (wep_checkout.id = 195).
--
-- Causa: em vw_checkouts, o join de fallback casa por (campanha, anúncio):
--
--     left join mkt_wep.dim_anuncios dn
--       on c.utm_campaign = dn.campanha
--      and c.utm_content  = dn.anuncio
--
-- Esse par NÃO é chave única. A campanha "...ad61-escala-baiana" tem 50 ad_ids
-- diferentes com o mesmo nome de anúncio (é uma escala de 1-50), então o join
-- devolveu 50 linhas para o mesmo checkout. Como fn_trafego conta linhas da
-- view, cada um dos 50 anúncios contou os 50 → 2.500.
--
-- Levantamento: 310 dos 1.094 pares (campanha, anúncio) do dim_anuncios têm
-- mais de um ad_id — o pior com 689. Ou seja, o defeito não é desta campanha:
-- qualquer checkout que caia num par ambíguo é multiplicado.
--
-- Alcance verificado ANTES da correção:
--   - vw_checkouts: 149 linhas para 100 checkouts reais (só o id 195 duplicado).
--   - vw_vendas: 61 linhas, 61 ids — nenhuma venda inflada HOJE, mas a view usa
--     exatamente o mesmo join (e sem nem ter o fallback por utm_id), então é o
--     mesmo bug esperando uma venda cair num par ambíguo. Corrigido junto.
--   - leads: 291 casam, 291 contados — sem inflação hoje. Ver nota no fim.
-- ============================================================================

-- ── 1) vw_vendas: dedup no join por nome ────────────────────────────────────
create or replace view mkt_wep.vw_vendas as
select
  v.id,
  v.tag,
  v.data,
  v.hora,
  v.status,
  v.produto,
  v.valor,
  v.parcelas,
  v.estado,
  v.tel_8d,
  mkt_wep.norm_pagina(v.utm_pagina) as pagina,
  d.ad_id,
  d.campanha,
  d.conjunto,
  d.anuncio,
  -- Venda válida = status 'APPROVED' (case-insensitive por segurança)
  (upper(coalesce(v.status, '')) = 'APPROVED') as venda_valida
from mkt_wep.wep_vendas v
-- lateral + limit 1: quando o par (campanha, anúncio) tem vários ad_ids, todos
-- compartilham campanha/conjunto/anuncio — só o ad_id é ambíguo. Pegamos o
-- menor, de forma determinística, em vez de multiplicar a venda.
left join lateral (
  select d0.ad_id, d0.campanha, d0.conjunto, d0.anuncio
    from mkt_wep.dim_anuncios d0
   where d0.campanha = v.utm_campaing   -- typo existente na tabela de origem
     and d0.anuncio  = v.utm_content
   order by d0.ad_id
   limit 1
) d on true;

-- ── 2) vw_checkouts: mesma correção, preservando o join exato por utm_id ────
create or replace view mkt_wep.vw_checkouts as
select
  c.id,
  c.tag,
  c.data,
  c.hora,
  c.tel_8d,
  mkt_wep.norm_pagina(c.utm_pagina) as pagina,
  coalesce(di.ad_id, dn.ad_id)       as ad_id,
  coalesce(di.campanha, dn.campanha) as campanha,
  coalesce(di.conjunto, dn.conjunto) as conjunto,
  coalesce(di.anuncio, dn.anuncio)   as anuncio
from mkt_wep.wep_checkout c
-- join exato por ad_id: ad_id é único no dim_anuncios (4808/4808), não duplica
left join mkt_wep.dim_anuncios di
  on c.utm_id = di.ad_id
-- fallback por nome, agora com limit 1 e só quando o join exato não resolveu
left join lateral (
  select d0.ad_id, d0.campanha, d0.conjunto, d0.anuncio
    from mkt_wep.dim_anuncios d0
   where di.ad_id is null
     and d0.campanha = c.utm_campaign
     and d0.anuncio  = c.utm_content
   order by d0.ad_id
   limit 1
) dn on true;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Nenhum checkout duplicado (esperado: 0 linhas):
select id, count(*) as vezes
  from mkt_wep.vw_checkouts
 group by id having count(*) > 1;

-- (b) Total de linhas = total de checkouts reais (esperado: iguais, 100):
select (select count(*) from mkt_wep.vw_checkouts) as linhas_view,
       (select count(*) from mkt_wep.wep_checkout) as checkouts_reais;

-- (c) Hoje deve ter 1 checkout, não 50:
select data, count(*) as checkouts
  from mkt_wep.vw_checkouts
 where data = current_date
 group by data;

-- (d) Vendas seguem intactas (esperado: 61 linhas, 61 ids, 60 válidas):
select count(*) as linhas, count(distinct id) as ids,
       count(*) filter (where venda_valida) as validas
  from mkt_wep.vw_vendas;

-- ── Nota: leads ─────────────────────────────────────────────────────────────
-- fn_trafego/fn_origem contam leads com o MESMO join ambíguo, direto na RPC
-- (sql/21_origem.sql, CTE "lds"). Hoje não infla porque nenhum lead caiu num
-- par ambíguo — verificado: 291 casam, 291 contados. Mas o risco é idêntico.
-- Corrigir exige recriar as RPCs, então ficou fora deste arquivo de propósito:
-- é mudança maior e merece ser feita e testada à parte.
