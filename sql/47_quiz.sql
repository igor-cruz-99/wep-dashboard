-- ============================================================================
-- QUIZ InLead — nova campanha de captação (ls-WEP-WEPAGO26-QUIZ-captacao-vendas).
-- Lead responde um quiz; respostas ficam em mkt_wep.wep_quiz (colunas diretas,
-- não JSON como wep_pesquisa). Mesmo padrão do fn_pesquisa_perfil: uma RPC só,
-- linhas (dimensao, categoria, total) já agrupadas no banco.
--
-- Por enquanto só os 4 campos pedidos (profissao, renda, alguem_na_rede,
-- ja_deu_conselhos) — a tabela tem mais colunas pra uso futuro; extender esta
-- função (mais um `union all select`) quando entrarem no dash.
-- ============================================================================
create or replace function mkt_wep.fn_quiz_perfil(
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
      nullif(btrim(profissao), '')        as profissao,
      nullif(btrim(renda), '')            as renda,
      nullif(btrim(alguem_na_rede), '')   as alguem_na_rede,
      nullif(btrim(ja_deu_conselhos), '') as ja_deu_conselhos
    from mkt_wep.wep_quiz
    where (p_tag  is null or tag = p_tag)
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  empilhado as (
    select 'profissao'::text     as dimensao, profissao        as categoria from base
    union all select 'renda',               renda                          from base
    union all select 'alguem_na_rede',       alguem_na_rede                 from base
    union all select 'ja_deu_conselhos',     ja_deu_conselhos               from base
  )
  select dimensao, categoria, count(*) as total
  from empilhado
  where categoria is not null
  group by dimensao, categoria
  order by dimensao, total desc, categoria;
$$;

-- Resumo: total de respostas do quiz (ao lado do título) + vendas (status
-- contém "Comprou", mostrado à direita do painel).
create or replace function mkt_wep.fn_quiz_resumo(
  p_tag text default null,
  p_from date default null,
  p_to date default null
)
returns table (respostas bigint, vendas bigint)
language sql
stable
as $$
  select
    count(*) as respostas,
    count(*) filter (where status ilike '%comprou%') as vendas
  from mkt_wep.wep_quiz
  where (p_tag  is null or tag = p_tag)
    and (p_from is null or data >= p_from)
    and (p_to   is null or data <= p_to);
$$;

-- Não precisa de revoke: o 07_lock_anon.sql já tranca privilégio padrão de
-- tabelas/funções novas em mkt_wep pra anon/authenticated.
