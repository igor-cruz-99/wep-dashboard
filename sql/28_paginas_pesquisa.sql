-- ============================================================================
-- fn_paginas + coluna PESQUISA por página — roda DEPOIS do 21.
--
-- A wep_pesquisa NÃO tem utm_pagina (só email). Então "pesquisa por página" =
-- respondentes cujo EMAIL casa com um lead (wep_cadastro), usando a utm_pagina
-- desse lead (normalizada). count(distinct email) por página.
--
-- ⚠️ Se ainda vier 0: é porque os emails da pesquisa (fictícia) não batem com os
--    da wep_cadastro. Com dados reais (mesma pessoa vira lead e responde), casa.
--
-- Muda o retorno (add pesquisa) → drop antes de recriar.
-- ============================================================================
drop function if exists mkt_wep.fn_paginas(date, date);
drop function if exists mkt_wep.fn_paginas(date, date, text);
create function mkt_wep.fn_paginas(
  p_from date default null,
  p_to date default null,
  p_origem text default null
)
returns table (
  pagina text,
  page_views bigint,
  checkouts bigint,
  vendas bigint,
  leads bigint,
  pesquisa bigint
)
language sql
stable
as $$
  with base as (
    select
      pagina,
      coalesce(sum(page_views), 0) as page_views,
      coalesce(sum(checkouts), 0)  as checkouts,
      coalesce(sum(vendas), 0)     as vendas
    from mkt_wep.vw_pagina_resumo
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and (p_origem is null or p_origem <> 'nativo')
    group by pagina
  ),
  lds as (
    select mkt_wep.norm_pagina(utm_pagina) as pagina, count(*) as leads
    from mkt_wep.wep_cadastro
    where utm_pagina is not null and btrim(utm_pagina) <> ''
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and utm_pagina = 'Forms_nativo')
           or (p_origem = 'pagina' and coalesce(utm_pagina, '') <> 'Forms_nativo'))
    group by mkt_wep.norm_pagina(utm_pagina)
  ),
  -- Pesquisa por página: respondente casado ao lead pelo email → utm_pagina do lead.
  pq as (
    select mkt_wep.norm_pagina(c.utm_pagina) as pagina,
           count(distinct lower(btrim(p.email))) as pesquisa
    from mkt_wep.wep_pesquisa p
    join mkt_wep.wep_cadastro c
      on lower(btrim(p.email)) = lower(btrim(c.email))
    where p.email is not null and btrim(p.email) <> ''
      and c.utm_pagina is not null and btrim(c.utm_pagina) <> ''
      and (p_from is null or p.data >= p_from) and (p_to is null or p.data <= p_to)
      and (p_origem is null or p_origem = 'todas'
           or (p_origem = 'nativo' and c.utm_pagina = 'Forms_nativo')
           or (p_origem = 'pagina' and coalesce(c.utm_pagina, '') <> 'Forms_nativo'))
    group by mkt_wep.norm_pagina(c.utm_pagina)
  )
  select
    coalesce(b.pagina, l.pagina)  as pagina,
    coalesce(b.page_views, 0)     as page_views,
    coalesce(b.checkouts, 0)      as checkouts,
    coalesce(b.vendas, 0)         as vendas,
    coalesce(l.leads, 0)          as leads,
    coalesce(pq.pesquisa, 0)      as pesquisa
  from base b
  full join lds l on b.pagina = l.pagina
  left join pq on pq.pagina = coalesce(b.pagina, l.pagina)
  where coalesce(b.pagina, l.pagina) not ilike '%tkp%'
  order by page_views desc;
$$;
