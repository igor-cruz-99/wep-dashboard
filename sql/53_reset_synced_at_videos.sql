-- 53_reset_synced_at_videos.sql
-- Contexto: o workflow "[Meta-Ads] Thumbnails" passou a capturar video_id via
-- creative.object_story_spec.video_data.video_id. Algumas linhas já tinham sido
-- sincronizadas pro Storage ANTES do video_id existir, então ficaram com a imagem
-- gravada, synced_at preenchido e storage_video_url null.
-- Como fn_ads_pendentes_wep só devolve linhas com synced_at is null, o job de sync
-- nunca mais revisita essas linhas pra baixar o vídeo. Este UPDATE recoloca elas na fila.
--
-- Escopo: só campanhas WEP (as outras 8 contas usam a mesma tabela).
-- Em 10/08/2026 isso atingia 6 linhas.

update core.ads_thumbnails t
   set synced_at = null
 where t.video_id is not null
   and t.storage_video_url is null
   and t.synced_at is not null
   and exists (
     select 1
       from mkt_wep.dim_anuncios d
      where d.ad_id::text = t.ad_id::text
        and d.campanha ilike '%wep%'
   );

-- conferência: deve devolver 0 depois de o job de sync rodar (20 min)
select count(*) as ainda_pendentes
  from core.ads_thumbnails t
 where t.video_id is not null
   and t.storage_video_url is null
   and exists (
     select 1
       from mkt_wep.dim_anuncios d
      where d.ad_id::text = t.ad_id::text
        and d.campanha ilike '%wep%'
   );
