-- ============================================================================
-- CPM, CPC, CTR e frequência no popup do criativo.
--
-- A galeria respondia só a pergunta de fundo de funil — gastou tanto, vendeu
-- tanto, CAC tal. Faltava a leitura de mídia: um criativo com CAC ruim pode
-- estar caro na entrega (CPM alto), sendo ignorado (CTR baixo) ou queimando a
-- audiência (frequência alta), e cada diagnóstico pede uma ação diferente.
--
-- As quatro saem das mesmas colunas que o funil já usa, com as mesmas fórmulas,
-- para o número do popup bater com o do funil quando o recorte coincidir:
--   CPM        = investimento / impressões * 1000
--   CPC        = investimento / cliques
--   CTR        = cliques / impressões * 100
--   Frequência = impressões / alcance
--
-- ⚠️ ALCANCE É SOMADO, e alcance não é aditivo: são pessoas únicas, então a
-- mesma pessoa alcançada em dois dias (ou em duas campanhas) conta duas vezes.
-- O alcance real é MENOR que essa soma e a frequência real, MAIOR. Mantive a
-- soma porque é exatamente o que a fn_funil já faz — um número consistente com
-- o resto do painel vale mais que um número certo isolado. Leia a frequência
-- da galeria como piso, não como valor exato. Só a API da Meta resolve isso de
-- verdade, consultando o alcance dedup por período.
--
-- Divisões protegidas: sem impressão não há CPM nem CTR, sem clique não há CPC,
-- sem alcance não há frequência. Nesses casos volta 0 e o front mostra "—", em
-- vez de inventar um número a partir de denominador zero.
-- ============================================================================
drop function if exists mkt_wep.fn_criativos_galeria(date, date, text[]);
create function mkt_wep.fn_criativos_galeria(
  p_from date default null,
  p_to date default null,
  p_excluir text[] default null
)
returns table (
  ad_name           text,
  tipo              text,
  storage_url       text,
  storage_video_url text,
  investimento      numeric,
  vendas            bigint,
  checkouts         bigint,
  cac               numeric,
  campanhas         bigint,
  alcance           numeric,
  impressoes        numeric,
  cliques           numeric,
  cpm               numeric,
  cpc               numeric,
  ctr               numeric,
  frequencia        numeric
)
language sql
stable
as $$
  with gasto as (
    -- Métricas por nome de anúncio, somando as campanhas em que rodou.
    select
      mkt_wep.norm_ad_name(a.anuncio) as chave,
      sum(a.gasto)                    as investimento,
      count(distinct a.campanha)      as campanhas,
      coalesce(sum(a.alcance), 0)     as alcance,
      coalesce(sum(a.impressoes), 0)  as impressoes,
      coalesce(sum(a.cliques), 0)     as cliques
    from mkt_wep.vw_ads_diario a
    where (p_from is null or a.data >= p_from)
      and (p_to   is null or a.data <= p_to)
      and a.campanha ilike '%wep%'
      and a.anuncio is not null
      and (p_excluir is null or not (a.campanha = any(p_excluir)))
    group by 1
    having sum(a.gasto) > 0
  ),
  vds as (
    select mkt_wep.norm_ad_name(anuncio) as chave,
           count(*) filter (where venda_valida) as vendas
    from mkt_wep.vw_vendas
    where (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
      and anuncio is not null
    group by 1
  ),
  cks as (
    select mkt_wep.norm_ad_name(anuncio) as chave,
           count(*) as checkouts
    from mkt_wep.vw_checkouts
    where (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
      and anuncio is not null
    group by 1
  ),
  midia as (
    -- Um criativo por chave: se houver mais de uma linha do catálogo com o
    -- mesmo nome normalizado, fica a que tem mídia.
    select distinct on (mkt_wep.norm_ad_name(c.ad_name))
      mkt_wep.norm_ad_name(c.ad_name) as chave,
      c.ad_name,
      c.tipo,
      c.storage_url,
      c.storage_video_url
    from mkt_wep.criativos_drive c
    where c.storage_url is not null or c.storage_video_url is not null
    order by mkt_wep.norm_ad_name(c.ad_name), c.storage_video_url nulls last, c.ad_name
  )
  select
    m.ad_name,
    m.tipo,
    m.storage_url,
    m.storage_video_url,
    round(g.investimento, 2)                as investimento,
    coalesce(v.vendas, 0)                   as vendas,
    coalesce(k.checkouts, 0)                as checkouts,
    case when coalesce(v.vendas, 0) > 0
         then round(g.investimento / v.vendas, 2)
         else 0 end                         as cac,
    g.campanhas,
    g.alcance,
    g.impressoes,
    g.cliques,
    case when g.impressoes > 0
         then round(g.investimento / g.impressoes * 1000, 2)
         else 0 end                         as cpm,
    case when g.cliques > 0
         then round(g.investimento / g.cliques, 2)
         else 0 end                         as cpc,
    case when g.impressoes > 0
         then round(g.cliques::numeric / g.impressoes * 100, 2)
         else 0 end                         as ctr,
    case when g.alcance > 0
         then round(g.impressoes::numeric / g.alcance, 2)
         else 0 end                         as frequencia
  from gasto g
  join midia m on m.chave = g.chave
  left join vds v on v.chave = g.chave
  left join cks k on k.chave = g.chave
  order by g.investimento desc;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) As quatro métricas nos 5 que mais gastaram.
--     ⚠️ Referência REAL desta conta, medida em 31/07-21/08 — não a referência
--     de mercado: CPM ~R$ 228, CPC ~R$ 14, CTR ~1,6%. O CPM é alto para Meta e
--     NÃO é erro de conta: nenhuma das 345 linhas tem gasto sem impressão, e os
--     3.922 cliques batem com os 3.838 page views do GA4, que é uma fonte
--     independente. O que o número diz é que a mídia está cara nesta operação.
--     Ele sobe ao longo do lançamento (R$ 98 em 31/07 -> R$ 426 em 17/08), que
--     é a assinatura de audiência saturando:
select ad_name, investimento, impressoes, cliques, cpm, cpc, ctr, frequencia
  from mkt_wep.fn_criativos_galeria('2026-07-31', '2026-08-21')
 limit 5;

-- (b) Nenhuma divisão por zero virou número esquisito — todo criativo sem
--     impressão/clique/alcance tem que estar zerado, nunca negativo ou nulo
--     (esperado: 0 linhas):
select ad_name, impressoes, cliques, alcance, cpm, cpc, ctr, frequencia
  from mkt_wep.fn_criativos_galeria('2026-07-31', '2026-08-21')
 where cpm < 0 or cpc < 0 or ctr < 0 or frequencia < 0
    or cpm is null or cpc is null or ctr is null or frequencia is null;

-- (c) Consistência com o funil: somando a galeria inteira, o CPM e o CTR ficam
--     PRÓXIMOS dos do funil, não idênticos — a galeria só inclui criativo com
--     mídia sincronizada, e o funil inclui todos. Se a diferença for grande, é
--     porque falta sincronizar mídia, não porque a conta está errada.
--     Medido em 31/07-21/08: CPM 227,47 / CTR 1,59 / freq 1,18 (esta última
--     subestimada pelo alcance somado, ver o aviso no topo):
select
  round(sum(investimento) / nullif(sum(impressoes), 0) * 1000, 2) as cpm_galeria,
  round(sum(cliques) / nullif(sum(impressoes), 0) * 100, 2)       as ctr_galeria,
  round(sum(impressoes) / nullif(sum(alcance), 0), 2)             as freq_galeria
  from mkt_wep.fn_criativos_galeria('2026-07-31', '2026-08-21');
