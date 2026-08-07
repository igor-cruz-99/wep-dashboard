-- ============================================================================
-- QUIZ InLead — ajustes pedidos pelo Igor:
-- 1) duas colunas novas: email (não vai pra gráfico, só guardado) e id_forms
--    (versão do formulário — usado no gráfico "Origem Quiz", pizza com a
--    contagem de linhas por versão).
-- 2) fn_quiz_perfil ganha duas dimensões: id_forms e quer_aprender.
-- ============================================================================
alter table mkt_wep.wep_quiz add column if not exists email text;
alter table mkt_wep.wep_quiz add column if not exists id_forms text;

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
      nullif(btrim(ja_deu_conselhos), '') as ja_deu_conselhos,
      nullif(btrim(quer_aprender), '')    as quer_aprender,
      nullif(btrim(id_forms), '')         as id_forms
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
    union all select 'quer_aprender',        quer_aprender                  from base
    union all select 'id_forms',             id_forms                       from base
  )
  select dimensao, categoria, count(*) as total
  from empilhado
  where categoria is not null
  group by dimensao, categoria
  order by dimensao, total desc, categoria;
$$;
