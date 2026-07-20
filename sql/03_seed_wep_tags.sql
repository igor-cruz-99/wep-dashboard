-- ============================================================================
-- Seed do wep_tags — 1 linha para o lançamento WEPAGO26.
-- Rodar DEPOIS do 02 (que adiciona as colunas meta_*).
-- ⚠️ AJUSTE as datas de captação e as metas para os valores reais do lançamento.
-- ============================================================================

insert into mkt_wep.wep_tags (
  tag,
  inicio_cap,          -- início da janela de captação (filtra ads/GA4)
  final_cap,           -- fim da janela de captação
  meta_vendas,
  meta_faturamento,
  meta_cac,
  meta_grupo,          -- meta da % Entrada Grupo
  meta_qualificacao    -- meta da % Qualificação
)
values (
  'WEPAGO26',
  '2026-07-01',        -- TODO: ajustar
  '2026-08-30',        -- TODO: ajustar
  150,                 -- TODO: meta real de vendas
  10000,               -- TODO: meta real de faturamento
  500,                 -- TODO: meta real de CAC
  85,                  -- TODO: meta real de entrada no grupo (%)
  80                   -- TODO: meta real de qualificação (%)
);

-- Se a coluna id não tiver default (gen_random_uuid), acrescente-a no insert:
--   insert into mkt_wep.wep_tags (id, tag, ...) values (gen_random_uuid(), 'WEPAGO26', ...);
