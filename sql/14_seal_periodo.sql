-- ============================================================================
-- SEAL POR PERÍODO — roda DEPOIS do 09_view_seal.sql (substitui o que ele criou).
--
-- Mudança: o bloco SEAL passa a respeitar o filtro de período do painel,
-- pela DATA DA COMPRA (core.vendas_pagarme.data), como o resto da página.
--
-- Por que a view virou função: `vw_seal_alunos` agregava por email sobre TODAS
-- as linhas, e view não aceita parâmetro. Como a classificação (quitou/reserva)
-- precisa considerar só as compras DENTRO do período, a agregação foi movida
-- para fn_seal_alunos(p_from, p_to), que as outras duas funções reaproveitam.
--
-- Consequência da regra: se o aluno pagou a reserva em março e o complemento
-- em maio, um filtro que pegue só março o classifica como "reserva" — porque
-- no período escolhido ele de fato só pagou a entrada.
-- ============================================================================

-- Objetos antigos (sem período) saem de cena.
drop function if exists mkt_wep.fn_seal_resumo();
drop function if exists mkt_wep.fn_seal_compradores();
drop view if exists mkt_wep.vw_seal_alunos;

-- ----------------------------------------------------------------------------
-- Base: 1 linha por aluno (email), considerando só as compras do período.
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_seal_alunos(
  p_from date default null,
  p_to date default null
)
returns table (email text, situacao text, valor_total numeric, pedidos bigint)
language sql
stable
as $$
  with base as (
    select
      lower(btrim(email)) as email,
      bool_or(produto ilike '%complemento%') as tem_complemento,
      bool_or(produto ilike '%seal%'
              and produto not ilike '%complemento%'
              and produto not ilike '%taxa de reserva%') as tem_integral,
      -- valor_cobrado vem string BR ("5.491,40").
      coalesce(sum(
        nullif(replace(replace(valor_cobrado, '.', ''), ',', '.'), '')::numeric
      ), 0) as valor_total,
      count(*) as pedidos
    from core.vendas_pagarme
    where status = 'paid'
      and produto ilike '%seal%'
      and email is not null and btrim(email) <> ''
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
    group by lower(btrim(email))
  )
  select
    email,
    case when tem_complemento or tem_integral then 'quitou' else 'reserva' end,
    valor_total,
    pedidos
  from base;
$$;

-- ----------------------------------------------------------------------------
-- Resumo dos cards (quitou / reserva) no período.
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_seal_resumo(
  p_from date default null,
  p_to date default null
)
returns table (situacao text, alunos bigint, valor_total numeric)
language sql
stable
as $$
  select situacao, count(*) as alunos, coalesce(sum(valor_total), 0) as valor_total
  from mkt_wep.fn_seal_alunos(p_from, p_to)
  group by situacao;
$$;

-- ----------------------------------------------------------------------------
-- Tabela de compradores no período (UTMs da venda, com fallback no pré-checkout).
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_seal_compradores(
  p_from date default null,
  p_to date default null
)
returns table (
  email        text,
  nome         text,
  situacao     text,
  utm_source   text,
  utm_campaign text,
  utm_medium   text,
  utm_content  text
)
language sql
stable
as $$
  with seal_rows as (
    select
      lower(btrim(email)) as email,
      nome_completo,
      data, hora,
      last_utm_source, last_utm_campaign, last_utm_medium, last_utm_content,
      (last_utm_campaign is not null and btrim(last_utm_campaign) <> '') as tem_utm
    from core.vendas_pagarme
    where status = 'paid'
      and produto ilike '%seal%'
      and email is not null and btrim(email) <> ''
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  melhor_venda as (
    select distinct on (email)
      email, nome_completo,
      last_utm_source, last_utm_campaign, last_utm_medium, last_utm_content
    from seal_rows
    order by email, tem_utm desc, data desc nulls last, hora desc nulls last
  ),
  prech as (
    select distinct on (lower(btrim(email)))
      lower(btrim(email)) as email,
      nome, utm_source, utm_campaign, utm_medium, utm_content
    from mkt_wep.wep_checkout
    where email is not null and btrim(email) <> ''
    order by lower(btrim(email)), created_at desc nulls last
  )
  select
    v.email,
    coalesce(nullif(btrim(v.nome_completo), ''), p.nome)              as nome,
    a.situacao,
    coalesce(nullif(btrim(v.last_utm_source), ''),   p.utm_source)    as utm_source,
    coalesce(nullif(btrim(v.last_utm_campaign), ''), p.utm_campaign)  as utm_campaign,
    coalesce(nullif(btrim(v.last_utm_medium), ''),   p.utm_medium)    as utm_medium,
    coalesce(nullif(btrim(v.last_utm_content), ''),  p.utm_content)   as utm_content
  from melhor_venda v
  join mkt_wep.fn_seal_alunos(p_from, p_to) a on a.email = v.email
  left join prech p on p.email = v.email
  order by a.situacao, v.email;
$$;
