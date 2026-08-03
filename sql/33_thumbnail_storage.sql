-- ============================================================================
-- THUMBNAIL — re-hospedagem permanente (Opção B).
--
-- Contexto: a automação (n8n) grava thumbnail_url/image_url direto da Meta,
-- que EXPIRAM. Uma automação nova (separada, ver plano n8n) baixa o arquivo de
-- verdade e sobe pro Supabase Storage, guardando aqui a URL permanente.
-- fn_ad_thumbnail prefere a URL do Storage; cai pra URL da Meta como
-- fallback só pra anúncios que ainda não passaram pelo job de sync.
--
-- Roda depois de sql/32 (que já deu ad_id à fn_trafego).
-- ============================================================================

-- ── 1) Colunas novas em core.ads_thumbnails ─────────────────────────────────
alter table core.ads_thumbnails add column if not exists video_id text;
alter table core.ads_thumbnails add column if not exists storage_url text;
alter table core.ads_thumbnails add column if not exists storage_video_url text;
alter table core.ads_thumbnails add column if not exists synced_at timestamptz;

-- TODO (quando o n8n marcar falha permanente — anúncio excluído/inacessível
-- na Meta): adicionar coluna sync_status/motivo em core.ads_thumbnails e
-- devolver aqui, pro popup mostrar "Anúncio excluído" em vez de "sem preview".
-- Ver front: src/components/tables/AdThumbnailModal.tsx.

-- ── 2) fn_ad_thumbnail — prefere Storage, cai pra Meta como fallback ───────
drop function if exists mkt_wep.fn_ad_thumbnail(text);
create function mkt_wep.fn_ad_thumbnail(p_ad_id text)
returns table (
  ad_id text,
  ad_name text,
  url text,        -- imagem: storage_url > image_url > thumbnail_url
  video_url text,   -- vídeo: só storage_video_url (a URL da Meta expira rápido
                     -- demais pra valer a pena expor antes do sync rodar)
  sincronizado boolean -- true = já passou pelo job de re-hospedagem
)
language sql
stable
as $$
  select
    ad_id,
    ad_name,
    coalesce(storage_url, image_url, thumbnail_url) as url,
    storage_video_url as video_url,
    (synced_at is not null) as sincronizado
  from core.ads_thumbnails
  where ad_id = p_ad_id
  limit 1;
$$;
