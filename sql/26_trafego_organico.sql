-- ============================================================================
-- TRÁFEGO x ORGÂNICO — leads por origem de aquisição (para o gráfico de pizza).
--
-- Orgânico = lead com utm_campaign vazia (null ou string em branco).
-- Tráfego  = o resto (tem utm_campaign preenchida).
-- Respeita tag + período (não usa o recorte de origem — é o quadro completo).
--
-- ⚠️ Hoje o formulário nativo chega com utm_campaign vazia, então esses leads
--    contam como "Orgânico". Se o nativo tiver que ser Tráfego, mudar a regra.
-- ============================================================================
drop function if exists mkt_wep.fn_trafego_organico(text, date, date);
create function mkt_wep.fn_trafego_organico(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (tipo text, leads bigint)
language sql
stable
as $$
  with c as (
    select
      count(*) filter (where coalesce(btrim(utm_campaign), '') <> '') as trafego,
      count(*) filter (where coalesce(btrim(utm_campaign), '') =  '') as organico
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  )
  select 'trafego'::text,  c.trafego  from c
  union all
  select 'organico'::text, c.organico from c;
$$;
