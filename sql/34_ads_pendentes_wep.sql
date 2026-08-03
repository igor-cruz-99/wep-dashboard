-- ============================================================================
-- FILTRAR O SYNC DE THUMBNAILS SÓ NAS CAMPANHAS WEP
--
-- core.ads_thumbnails guarda anúncios de TODOS os projetos (Patrimonium,
-- Funil 360, Alpes, QV1-4, WEP...) — o job de sync do n8n só precisa
-- re-hospedar os anúncios do WEP, resto é peso desnecessário (backlog maior,
-- chamadas à Meta gastas à toa). Mesmo critério já usado no resto do projeto:
-- campanha ILIKE '%wep%' (mkt_wep.dim_anuncios).
-- ============================================================================
drop function if exists mkt_wep.fn_ads_pendentes_wep(int);
create function mkt_wep.fn_ads_pendentes_wep(p_limit int default 20)
returns table (
  ad_id text,
  image_url text,
  thumbnail_url text,
  video_id text
)
language sql
stable
as $$
  select t.ad_id, t.image_url, t.thumbnail_url, t.video_id
  from core.ads_thumbnails t
  where t.synced_at is null
    and t.ad_id in (select ad_id from mkt_wep.dim_anuncios)
  order by t.ad_id
  limit p_limit;
$$;
