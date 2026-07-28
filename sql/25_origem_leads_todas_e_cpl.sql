-- ============================================================================
-- ORIGEM DOS LEADS (mostrar todas, mesmo zeradas) + CPL POR ORIGEM.
--
-- 1) fn_origem_leads: passa a mostrar TODAS as origens conhecidas (v1, h1..h4 v2,
--    formulário nativo) mesmo com 0 leads — via uma lista fixa (universe) com
--    LEFT JOIN nas contagens. Ignora o recorte de origem de propósito: a tabela
--    é o quadro completo (o % é sobre o total). Se surgir uma origem nova que já
--    tem lead, ela também aparece (union com o que veio do banco).
--    ⚠️ Ao lançar uma variante nova (ex.: h5v2), adicione na lista VALUES abaixo.
--
-- 2) fn_cpl_origem: CPL separado Páginas x Forms nativo (investimento ÷ leads de
--    cada lado). Respeita tag/período; sempre devolve as duas linhas.
-- ============================================================================

-- ── 1) fn_origem_leads (todas as origens, inclusive zeradas) ────────────────
drop function if exists mkt_wep.fn_origem_leads(text, date, date, text);
create function mkt_wep.fn_origem_leads(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null   -- ignorado de propósito (quadro completo)
)
returns table (origem text, leads bigint, pct numeric)
language sql
stable
as $$
  with base as (
    select
      case
        when utm_pagina = 'Forms_nativo' then 'Formulário nativo'
        when utm_pagina is null or btrim(utm_pagina) = '' then '(sem origem)'
        else mkt_wep.norm_pagina(utm_pagina)
      end as origem,
      count(*) as leads
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
    group by 1
  ),
  universe as (
    select origem from (values
      ('/imersao-engenheiro-patrimonial-wep-cap-v1'),
      ('/imersao-engenheiro-patrimonial-cap-h1v2-wep'),
      ('/imersao-engenheiro-patrimonial-cap-h2v2-wep'),
      ('/imersao-engenheiro-patrimonial-cap-h3v2-wep'),
      ('/imersao-engenheiro-patrimonial-cap-h4v2-wep'),
      ('Formulário nativo')
    ) as u(origem)
    union
    select origem from base   -- inclui qualquer origem nova que já tenha lead
  ),
  tot as (select coalesce(sum(leads), 0) as t from base)
  select
    u.origem,
    coalesce(b.leads, 0) as leads,
    case when tot.t > 0 then round(100.0 * coalesce(b.leads, 0) / tot.t, 1) else 0 end as pct
  from universe u
  left join base b on b.origem = u.origem
  cross join tot
  order by leads desc, u.origem;
$$;

-- ── 2) fn_cpl_origem (CPL Páginas x Forms nativo) ───────────────────────────
drop function if exists mkt_wep.fn_cpl_origem(text, date, date);
create function mkt_wep.fn_cpl_origem(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (origem text, investimento numeric, leads bigint, cpl numeric)
language sql
stable
as $$
  with
  inv_p as (
    select coalesce(sum(gasto), 0) as g
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and (campanha is null or campanha not ilike '%forms-nativo%')
  ),
  inv_n as (
    select coalesce(sum(gasto), 0) as g
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and campanha ilike '%forms-nativo%'
  ),
  led_p as (
    select count(*) as c
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and coalesce(utm_pagina, '') <> 'Forms_nativo'
  ),
  led_n as (
    select count(*) as c
    from mkt_wep.wep_cadastro
    where (p_tag is null or tag = p_tag)
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and utm_pagina = 'Forms_nativo'
  )
  select 'pagina'::text, inv_p.g, led_p.c,
         case when led_p.c > 0 then round(inv_p.g / led_p.c, 2) else 0 end
  from inv_p, led_p
  union all
  select 'nativo'::text, inv_n.g, led_n.c,
         case when led_n.c > 0 then round(inv_n.g / led_n.c, 2) else 0 end
  from inv_n, led_n;
$$;
