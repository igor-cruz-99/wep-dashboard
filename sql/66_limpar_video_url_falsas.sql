-- ============================================================================
-- Limpa os storage_video_url da Meta que apontam para arquivos inexistentes.
--
-- Histórico: o workflow "[Meta-Ads] Sync thumbnails → Storage" montava a URL do
-- vídeo por convenção e gravava mesmo quando o upload falhava. Resultado
-- verificado em 10/08: 130 linhas com storage_video_url preenchido e ZERO
-- arquivos .mp4 no bucket. Toda essa coluna aponta para 404.
--
-- Hoje isso não quebra nada — o popup tenta o vídeo, falha e cai na imagem —
-- mas é uma requisição perdida a cada abertura, e o "sincronizado" da RPC fica
-- mentindo. Os vídeos que existem de verdade vivem em mkt_wep.criativos_drive,
-- não aqui.
--
-- Só mexe em core.ads_thumbnails (Meta). Não toca em criativos_drive.
-- ============================================================================

-- Confere antes: quantas linhas serão limpas e quantos .mp4 existem de fato
-- no bucket vindos da Meta (esperado: 130 e nenhum).
select count(*) as urls_de_video_falsas
  from core.ads_thumbnails
 where storage_video_url is not null;

update core.ads_thumbnails
   set storage_video_url = null
 where storage_video_url is not null;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Nenhuma URL de vídeo sobrando na tabela da Meta (esperado: 0):
select count(*) as ainda_com_video from core.ads_thumbnails where storage_video_url is not null;

-- (b) As imagens da Meta seguem intactas — é o fallback dos 270 anúncios que
--     não estão na planilha do SEAL (esperado: ~300):
select count(*) as imagens_da_meta from core.ads_thumbnails where storage_url is not null;

-- (c) Os vídeos de verdade continuam no lugar certo (esperado: 3):
select count(*) as videos_do_drive from mkt_wep.criativos_drive where storage_video_url is not null;
