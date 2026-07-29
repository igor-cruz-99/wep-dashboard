-- ============================================================================
-- SLUG: engenheiro → estrategista (consolidar páginas de captação renomeadas).
--
-- As páginas mudaram de "imersao-engenheiro-patrimonial" para
-- "imersao-estrategista-patrimonial". Dados antigos ficaram com o slug velho,
-- gerando linhas DUPLICADAS. Consolidamos assim:
--
-- 1) norm_pagina passa a reescrever o prefixo antigo no NORMALIZADOR. Como todo
--    caminho (GA4, leads, vendas, checkout) passa por norm_pagina, isso
--    consolida tudo NA LEITURA — inclusive o GA4 (core.paginas_ga4), que é fonte
--    bruta compartilhada e NÃO deve ser alterada. Bônus: lead novo que ainda
--    chegue como "engenheiro" (antes de trocar a fórmula do Make) já cai
--    consolidado, sem duplicar.
--
-- 2) UPDATE nos leads antigos (wep_cadastro é nossa tabela) — deixa o dado
--    gravado limpo também.
--
-- 3) fn_origem_leads: lista fixa (universe) passa a usar o slug novo.
--
-- ⚠️ Também troque a fórmula do Make (engenheiro→estrategista) pra novos leads
--    já gravarem o slug novo.
-- ============================================================================

-- 1) NORMALIZADOR — reescreve o prefixo antigo. (lower() já roda antes, então o
--    replace do texto minúsculo casa; não há índice funcional sobre norm_pagina.)
create or replace function mkt_wep.norm_pagina(p text)
returns text
language sql
immutable
as $$
  select replace(
    rtrim(
      regexp_replace(
        regexp_replace(lower(coalesce(p, '')), '^https?://[^/]+', ''),
        '[?#].*$', ''
      ),
      '/'
    ),
    'imersao-engenheiro-patrimonial', 'imersao-estrategista-patrimonial'
  );
$$;

-- 2) DADOS antigos dos leads (nossa tabela) — troca o slug gravado.
update mkt_wep.wep_cadastro
set utm_pagina = replace(utm_pagina, 'imersao-engenheiro-patrimonial', 'imersao-estrategista-patrimonial')
where utm_pagina ilike '%imersao-engenheiro-patrimonial%';

-- 3) fn_origem_leads — universe com o slug novo (pra mostrar zeradas certas).
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
      ('/imersao-estrategista-patrimonial-wep-cap-v1'),
      ('/imersao-estrategista-patrimonial-cap-h1v2-wep'),
      ('/imersao-estrategista-patrimonial-cap-h2v2-wep'),
      ('/imersao-estrategista-patrimonial-cap-h3v2-wep'),
      ('/imersao-estrategista-patrimonial-cap-h4v2-wep'),
      ('Formulário nativo')
    ) as u(origem)
    union
    select origem from base
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
