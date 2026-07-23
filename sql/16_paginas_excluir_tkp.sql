-- ============================================================================
-- fn_paginas: exclui páginas que contenham "tkp" (thank-you/obrigado).
--
-- Não devem aparecer na tabela "Desempenho por página". Filtro por not ilike
-- '%tkp%' sobre o caminho já normalizado. Retorno inalterado → create or replace.
-- ============================================================================
create or replace function mkt_wep.fn_paginas(
  p_from date default null,
  p_to date default null
)
returns table (
  pagina text,
  page_views bigint,
  checkouts bigint,
  vendas bigint,
  leads bigint
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
    group by pagina
  ),
  lds as (
    select mkt_wep.norm_pagina(utm_pagina) as pagina, count(*) as leads
    from mkt_wep.wep_cadastro
    where utm_pagina is not null and btrim(utm_pagina) <> ''
      and (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by mkt_wep.norm_pagina(utm_pagina)
  )
  select
    coalesce(b.pagina, l.pagina)  as pagina,
    coalesce(b.page_views, 0)     as page_views,
    coalesce(b.checkouts, 0)      as checkouts,
    coalesce(b.vendas, 0)         as vendas,
    coalesce(l.leads, 0)          as leads
  from base b
  full join lds l on b.pagina = l.pagina
  where coalesce(b.pagina, l.pagina) not ilike '%tkp%'  -- fora as páginas de obrigado
  order by page_views desc;
$$;
