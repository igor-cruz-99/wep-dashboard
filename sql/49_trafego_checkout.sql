-- ============================================================================
-- Adiciona CHECKOUT à fn_trafego (Análise de tráfego) — Padrão precisa dessa
-- coluna (é venda direta: sem lead, mas o checkout é a etapa intermediária
-- que interessa acompanhar por campanha/conjunto/anúncio).
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
    select campanha, conjunto, anuncio, ad_id,
           sum(gasto) as gasto,
           sum(impressoes) as imp,
           sum(video_3s) as v3,
           sum(video_25p) as v25,
           sum(video_50p) as v50
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio, ad_id))
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
