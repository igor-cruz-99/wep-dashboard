-- ============================================================================
-- SEAL — situação de pagamento por aluno (roadmap item 2)
--
-- Fonte: core.vendas_pagarme. Três nomes de produto compõem o SEAL:
--   'Seal® - Taxa de Reserva'  → pagou só a entrada
--   'SEAL - Complemento'       → pagou o restante
--   'Seal®'                    → pagou tudo de uma vez
--
-- Regra (definida com o Igor): o agrupamento é pelo EMAIL do aluno.
--   - pagou complemento OU integral  → QUITOU (pagou tudo)
--   - só a taxa de reserva           → RESERVA (só a entrada)
-- Complemento sozinho conta como quitou: quem paga o restante (~R$4.500+)
-- fechou o negócio, ainda que a reserva esteja em outro email/ausente.
--
-- Escopo: TODAS as vendas SEAL (qualquer origem), status = 'paid'.
-- ============================================================================

create or replace view mkt_wep.vw_seal_alunos as
with base as (
  select
    lower(btrim(email)) as email,
    bool_or(produto ilike '%taxa de reserva%')                            as tem_reserva,
    bool_or(produto ilike '%complemento%')                                as tem_complemento,
    bool_or(produto ilike '%seal%'
            and produto not ilike '%complemento%'
            and produto not ilike '%taxa de reserva%')                    as tem_integral,
    -- valor_cobrado vem string BR ("5.491,40"): tira o ponto de milhar e
    -- troca a vírgula decimal por ponto antes de somar.
    coalesce(sum(
      nullif(replace(replace(valor_cobrado, '.', ''), ',', '.'), '')::numeric
    ), 0) as valor_total,
    count(*) as pedidos
  from core.vendas_pagarme
  where status = 'paid'
    and produto ilike '%seal%'
    and email is not null and btrim(email) <> ''
  group by lower(btrim(email))
)
select
  email,
  case when tem_complemento or tem_integral then 'quitou' else 'reserva' end as situacao,
  valor_total,
  pedidos
from base;

-- ----------------------------------------------------------------------------
-- Resumo para os 2 cards: uma linha por situação (quitou / reserva).
-- Sem filtros — os cards mostram sempre o total do produto SEAL.
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_seal_resumo()
returns table (situacao text, alunos bigint, valor_total numeric)
language sql
stable
as $$
  select situacao, count(*) as alunos, coalesce(sum(valor_total), 0) as valor_total
  from mkt_wep.vw_seal_alunos
  group by situacao;
$$;

-- ----------------------------------------------------------------------------
-- Tabela de compradores SEAL: nome, email e UTMs (1 linha por email).
--
-- UTMs: usa os da própria venda (last_utm_*); quando vierem vazios (acontece
-- em algumas linhas de reserva/complemento), faz fallback pelo EMAIL na tabela
-- de pré-checkout (mkt_wep.wep_checkout), que guarda os UTMs da captação.
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.fn_seal_compradores()
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
  ),
  -- Por email, escolhe a linha que TEM utm (senão a mais recente).
  melhor_venda as (
    select distinct on (email)
      email, nome_completo,
      last_utm_source, last_utm_campaign, last_utm_medium, last_utm_content
    from seal_rows
    order by email, tem_utm desc, data desc nulls last, hora desc nulls last
  ),
  -- Fallback: UTMs do pré-checkout, 1 registro por email (o mais recente).
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
  join mkt_wep.vw_seal_alunos a on a.email = v.email
  left join prech p on p.email = v.email
  order by a.situacao, v.email;
$$;

-- Sem revoke: o 07_lock_anon.sql já revoga select/execute futuros para
-- anon/authenticated. Só a service_role (via /api/dashboard) acessa.
