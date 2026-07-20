-- ============================================================================
-- Índice para acelerar o filtro campanha ILIKE '%wep%' no core.ads_metrics.
-- Um índice pg_trgm (trigramas) permite que o "contém" use índice em vez de
-- varrer a tabela toda. Some com a lentidão / risco de timeout.
--
-- É transparente: só acelera leitura, não muda nenhum dado nem o app existente.
-- ============================================================================

-- 1) Habilita a extensão de trigramas (idempotente).
--    Se der erro de permissão, habilite pelo painel:
--    Database → Extensions → pg_trgm (toggle ON).
create extension if not exists pg_trgm;

-- 2) Cria o índice SEM travar escrita (CONCURRENTLY).
--    ⚠️ RODE ESTA LINHA SOZINHA (CONCURRENTLY não roda dentro de transação).
--    Se o SQL Editor reclamar de "cannot run inside a transaction block",
--    execute só este comando, isolado.
create index concurrently if not exists idx_ads_metrics_campanha_trgm
  on core.ads_metrics
  using gin (campanha gin_trgm_ops);
