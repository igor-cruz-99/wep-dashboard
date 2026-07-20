-- ----------------------------------------------------------------------------
-- PERFIL DAS PESQUISAS (roadmap item 3)
--
-- Uma RPC só para os 4 gráficos. Devolve linhas (dimensao, categoria, total)
-- já agrupadas e contadas no banco — o front nunca recebe linha a linha.
--
-- Fonte: mkt_wep.wep_pesquisa
--   - `renda` é coluna própria;
--   - `idade`, `genero` e `profissao` moram no JSON `respostas`.
-- Respeita os mesmos filtros do resto do painel (tag + período).
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_pesquisa_perfil(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (dimensao text, categoria text, total bigint)
language sql
stable
as $$
  with base as (
    select
      nullif(btrim(renda), '')                        as renda,
      nullif(btrim(respostas ->> 'idade'), '')        as idade,
      nullif(btrim(respostas ->> 'profissao'), '')    as profissao,
      nullif(btrim(respostas ->> 'genero'), '')       as genero
    from mkt_wep.wep_pesquisa
    where (p_tag  is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  -- Empilha as 4 dimensões numa coluna só; assim um único group by resolve tudo.
  empilhado as (
    select 'renda'::text     as dimensao, renda     as categoria from base
    union all select 'idade',             idade                  from base
    union all select 'profissao',         profissao              from base
    union all select 'genero',            genero                 from base
  )
  select dimensao, categoria, count(*) as total
  from empilhado
  where categoria is not null  -- resposta em branco não vira fatia/barra
  group by dimensao, categoria
  order by dimensao, total desc, categoria;
$$;

-- Não precisa de revoke: o 07_lock_anon.sql já definiu `alter default
-- privileges ... revoke execute on functions`, então esta função nasce
-- inacessível para anon/authenticated. Só a service_role (via /api/dashboard) usa.
