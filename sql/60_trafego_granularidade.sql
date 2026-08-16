-- ============================================================================
-- BUG (parte 2): a "Análise de tráfego" mostrava 50 checkouts onde existe 1,
-- e repetia o mesmo anúncio em 50 linhas.
--
-- O sql/59 consertou a duplicação dentro da vw_checkouts. Este arquivo conserta
-- o segundo ponto, que fica dentro da própria fn_trafego.
--
-- Causa: o sql/32 (popup de thumbnail) passou a agrupar o CTE "ads" por
-- (campanha, conjunto, anuncio, ad_id) para expor o ad_id. Mas os CTEs de
-- conversão — cks (checkouts), vds (vendas) e lds (leads) — continuaram
-- agrupando por (campanha, conjunto, anuncio), e o join entre eles é por NOME.
-- Numa campanha de escala (o mesmo criativo subido em 50 cópias, 50 ad_ids
-- com o mesmo nome), cada cópia recebia a métrica inteira do grupo.
--
-- Medido antes da correção:
--   hoje:    59 linhas de anúncio para 10 nomes reais; 50 checkouts para 1 real.
--   30 dias: 162 linhas para 108 nomes; 140 checkouts para 91 reais.
--   (vendas e leads não estavam inflados por acaso — nenhum anúncio com venda
--    ou lead caiu num grupo ambíguo. A mecânica era a mesma.)
--
-- Correção: "ads" volta a agrupar por nome, alinhando com os CTEs de conversão.
-- O ad_id passa a ser um representante do grupo (min), que é o suficiente para
-- o popup de preview — ainda mais agora que a mídia é casada por NOME na
-- mkt_wep.criativos_drive (sql/55).
--
-- Efeito visível: uma linha por anúncio, com o investimento das cópias somado.
-- Decisão do Igor em 14/08/2026: prefere consolidado a comparar cópia a cópia.
-- ============================================================================
drop function if exists mkt_wep.fn_trafego(date, date, text, text[]);
create function mkt_wep.fn_trafego(
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_excluir text[] default null
)
returns table (
  nivel text,
  campanha text,
  conjunto text,
  anuncio text,
  ad_id text,
  investimento numeric,
  vendas bigint,
  checkouts bigint,
  leads bigint,
  cac numeric,
  hook numeric,
  hold numeric,
  body numeric
)
language sql
stable
as $$
  with ads as (
    select campanha, conjunto, anuncio,
           -- representante do grupo: com N cópias do mesmo criativo, qualquer
           -- ad_id serve para o preview (a mídia é casada por nome). Antes o
           -- ad_id estava no group by e era ele que multiplicava as linhas.
           min(ad_id) as ad_id,
           sum(gasto) as gasto,
           sum(impressoes) as imp,
           sum(video_3s) as v3,
           sum(video_25p) as v25,
           sum(video_50p) as v50
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio))
  ),
  vds as (
    select campanha, conjunto, anuncio,
           count(*) filter (where venda_valida) as vendas
    from mkt_wep.vw_vendas
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio))
  ),
  cks as (
    select campanha, conjunto, anuncio,
           count(*) as checkouts
    from mkt_wep.vw_checkouts
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio))
  ),
  lds as (
    select d.campanha, d.conjunto, d.anuncio, count(*) as leads
    from mkt_wep.wep_cadastro c
    join mkt_wep.dim_anuncios d
      on  c.utm_campaign = d.campanha
      and c.utm_content  = d.anuncio
    where (p_from is null or c.data >= p_from) and (p_to is null or c.data <= p_to)
    group by grouping sets ((d.campanha), (d.campanha, d.conjunto), (d.campanha, d.conjunto, d.anuncio))
  )
  select
    case
      when ads.anuncio is not null then 'anuncio'
      when ads.conjunto is not null then 'conjunto'
      else 'campanha'
    end as nivel,
    ads.campanha, ads.conjunto, ads.anuncio, ads.ad_id,
    ads.gasto as investimento,
    coalesce(vds.vendas, 0) as vendas,
    coalesce(cks.checkouts, 0) as checkouts,
    coalesce(lds.leads, 0) as leads,
    case when coalesce(vds.vendas,0) > 0 then round(ads.gasto / vds.vendas, 2) else 0 end as cac,
    case when ads.imp > 0 then round(100.0 * ads.v3  / ads.imp, 1) else 0 end as hook,
    case when ads.v3  > 0 then round(100.0 * ads.v25 / ads.v3,  1) else 0 end as hold,
    case when ads.imp > 0 then round(100.0 * ads.v50 / ads.imp, 1) else 0 end as body
  from ads
  left join vds
    on  ads.campanha is not distinct from vds.campanha
    and ads.conjunto is not distinct from vds.conjunto
    and ads.anuncio  is not distinct from vds.anuncio
  left join cks
    on  ads.campanha is not distinct from cks.campanha
    and ads.conjunto is not distinct from cks.conjunto
    and ads.anuncio  is not distinct from cks.anuncio
  left join lds
    on  ads.campanha is not distinct from lds.campanha
    and ads.conjunto is not distinct from lds.conjunto
    and ads.anuncio  is not distinct from lds.anuncio
  where ads.campanha ilike '%wep%'
    and (p_origem is null or p_origem = 'todas'
         or (p_origem = 'nativo' and ads.campanha ilike '%forms-nativo%')
         or (p_origem = 'pagina' and ads.campanha not ilike '%forms-nativo%'))
    and (p_excluir is null or ads.campanha is null or not (ads.campanha = any(p_excluir)))
  order by ads.campanha, ads.conjunto nulls first, ads.anuncio nulls first;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) HOJE: esperado 10 linhas de anúncio (era 59) e 1 checkout no total (era 50):
select count(*) as linhas_anuncio, sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.fn_trafego(current_date, current_date)
 where nivel = 'anuncio';

-- (b) Nenhum nome de anúncio deve aparecer duas vezes (esperado: 0 linhas):
select campanha, conjunto, anuncio, count(*) as vezes
  from mkt_wep.fn_trafego(current_date - 30, current_date)
 where nivel = 'anuncio'
 group by campanha, conjunto, anuncio
having count(*) > 1;

-- (c) 30 DIAS: esperado 108 linhas (era 162) e 91 checkouts (era 140).
--     Investimento NÃO pode mudar — só foi reagrupado, não refiltrado:
select count(*) as linhas_anuncio,
       sum(checkouts) as checkouts,
       sum(vendas) as vendas,
       sum(leads) as leads,
       round(sum(investimento), 2) as investimento
  from mkt_wep.fn_trafego(current_date - 30, current_date)
 where nivel = 'anuncio';
