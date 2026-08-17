-- ============================================================================
-- A fn_trafego leva 2.008 ms DENTRO do banco (medido com explain analyze).
-- Não é rede nem fila de conexão — é a query mesmo.
--
-- Onde o tempo vai, pelo plano:
--   cks (checkouts) 992 ms | vds (vendas) 815 ms | lds (leads) 174 ms
--
-- Causa: para cada checkout/venda/lead, o banco busca o anúncio em
-- core.ads_metrics com a condição
--     campanha ilike '%wep%'  AND  campanha = <valor>
-- e o único índice disponível é o TRIGRAM (idx_ads_metrics_campanha_trgm).
-- Trigram serve para busca parcial ('%wep%'), não para igualdade: o plano
-- mostra "Rows Removed by Index Recheck: 4923" e 57.039 blocos lidos só no
-- bloco de checkouts, com o lookup repetido 141 vezes.
--
-- Falta um índice btree de igualdade em (campanha, anuncio) — que é
-- exatamente como as views casam o registro com o anúncio.
--
-- ATENÇÃO: core.ads_metrics é compartilhada com os outros projetos. Um índice
-- a mais custa um pouco de escrita, mas beneficia qualquer consulta que filtre
-- por campanha/anúncio, não só o WEP.
--
-- SEM CONCURRENTLY: o SQL Editor do Supabase roda tudo dentro de transação e
-- CONCURRENTLY é proibido nesse contexto (ERRO 25001). A consequência é que a
-- tabela fica bloqueada para ESCRITA durante a criação — alguns segundos numa
-- tabela deste tamanho. Quem tentar gravar nesse intervalo espera e depois
-- grava normalmente; não se perde dado. Se preferir risco zero, rode fora do
-- horário em que as automações do n8n estão sincronizando.
-- ============================================================================

-- ── Antes: veja o tempo atual (esperado ~2000 ms) ──────────────────────────
explain (analyze)
select * from mkt_wep.fn_trafego(current_date - 30, current_date);

-- ── O índice que falta ─────────────────────────────────────────────────────
-- Cobre o casamento por nome usado em vw_checkouts, vw_vendas e no CTE de
-- leads da fn_trafego.
create index if not exists idx_ads_metrics_campanha_anuncio
  on core.ads_metrics (campanha, anuncio);

-- Cobre o casamento exato por ad_id (vw_checkouts usa utm_id = ad_id).
create index if not exists idx_ads_metrics_ad_id
  on core.ads_metrics (ad_id);

-- Atualiza as estatísticas para o planejador enxergar os índices novos.
analyze core.ads_metrics;

-- ── Depois: rode de novo e compare ─────────────────────────────────────────
-- Esperado: queda expressiva, e o plano deve trocar o Bitmap Index Scan sobre
-- o índice trigram por Index Scan nos índices novos.
explain (analyze)
select * from mkt_wep.fn_trafego(current_date - 30, current_date);

-- ── Conferência: os números não podem mudar ────────────────────────────────
-- Índice só muda velocidade, nunca resultado. Esperado igual à baseline:
-- 291 leads, R$ 67.007,70, 115 checkouts, 64 vendas.
select sum(leads) as leads,
       round(sum(investimento), 2) as investimento,
       sum(checkouts) as checkouts,
       sum(vendas) as vendas
  from mkt_wep.fn_trafego(current_date - 30, current_date)
 where nivel = 'anuncio';
