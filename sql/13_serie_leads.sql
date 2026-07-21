-- ============================================================================
-- SÉRIE DIÁRIA + LEADS — roda DEPOIS do 11_leads.sql (precisa da wep_cadastro).
--
-- Acrescenta `leads` por dia na fn_serie_diaria, para o gráfico combo
-- "Leads por dia | Conversão" (barras = leads; a conversão vendas/leads é
-- calculada no front a partir de vendas + leads do mesmo dia).
--
-- ⚠️ Muda o retorno da função → drop antes de recriar.
-- ============================================================================
drop function if exists mkt_wep.fn_serie_diaria(text, date, date);
create function mkt_wep.fn_serie_diaria(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (
  data date,
  vendas int,
  investimento numeric,
  cac numeric,
  conversao numeric,
  leads int
)
language sql
stable
as $$
  with vd as (
    select data, count(*) filter (where venda_valida) as vendas
    from mkt_wep.vw_vendas
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by data
  ),
  ad as (
    select data, sum(gasto) as gasto
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by data
  ),
  ck as (
    select data, count(*) as checkouts
    from mkt_wep.vw_checkouts
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by data
  ),
  ld as (
    select data, count(*) as leads
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by data
  )
  select
    d.data,
    coalesce(vd.vendas, 0)  as vendas,
    coalesce(ad.gasto, 0)   as investimento,
    case when coalesce(vd.vendas, 0) > 0
         then round(coalesce(ad.gasto, 0) / vd.vendas, 2) else 0 end as cac,
    -- Conversão Checkout = Vendas ÷ Checkouts (%)
    case when coalesce(ck.checkouts, 0) > 0
         then round(100.0 * coalesce(vd.vendas, 0) / ck.checkouts, 2) else 0 end as conversao,
    coalesce(ld.leads, 0)   as leads
  from (
    select data from vd
    union select data from ad
    union select data from ck
    union select data from ld
  ) d
  left join vd on vd.data = d.data
  left join ad on ad.data = d.data
  left join ck on ck.data = d.data
  left join ld on ld.data = d.data
  order by d.data;
$$;
