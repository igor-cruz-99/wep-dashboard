-- ============================================================================
-- SEAL: a situação passa a sair do VALOR PAGO, não do nome do produto.
--
-- O problema: a regra antiga classificava pelo texto do produto — "complemento"
-- ou "seal sem taxa de reserva" viravam 'quitou', o resto 'reserva'. Só que o
-- produto na origem hoje se chama APENAS "SEAL" nas 8 linhas do período: não
-- existe mais "taxa de reserva" nem "complemento" no nome. Com isso a condição
-- `produto not ilike '%taxa de reserva%'` era verdadeira para todo mundo e os
-- 7 alunos caíam em 'quitou', inclusive os cinco que pagaram R$ 500.
--
-- O painel mostrava, então, "7 quitaram" somando R$ 7,5 mil — sete alunos que
-- teriam pago tudo, com um total que não paga nem dois SEAL. O card estava
-- coerente consigo mesmo e errado sobre o mundo.
--
-- A regra nova, definida pelo Igor: abaixo de R$ 3.000 é COMPLEMENTO (pagou uma
-- parte), de R$ 3.000 para cima é COMPLETA (pagou o SEAL inteiro).
--
-- Sobre o limiar: o pedido foi "abaixo de 3000" e "acima de 3001", o que deixa
-- o intervalo entre 3.000 e 3.001 sem dono. Fechei em 3.000 como divisor único
-- (>= 3000 é completa) para não existir valor sem classificação. Na prática os
-- valores reais são ~R$ 500 e ~R$ 4.500, bem longe da fronteira dos dois lados.
--
-- Continua agregando por EMAIL e somando o período: quem pagou a entrada e
-- depois o restante soma os dois e vira completa — que é o certo, porque o
-- aluno pagou o SEAL inteiro, ainda que em dois pedidos. É o caso real do
-- fabiomarquesmail (R$ 500 + R$ 4.770,59 = R$ 5.270,59).
--
-- ⚠️ EFEITO NOS CARDS: a distribuição vira 2 completas e 5 complementos, no
-- lugar de 7 quitados e 0 reservas. Não é dado novo, é a mesma venda lida
-- direito. O CAC SEAL, que divide pelas vendas completas, sobe na mesma
-- proporção — o número antigo tratava um pagamento de R$ 500 como aluno
-- adquirido.
--
-- valor_cobrado é TEXT em formato BR ("5.491,40"): tira o ponto de milhar e
-- troca a vírgula por ponto antes de virar numeric. Mesmo tratamento que já
-- existia, só que agora o resultado também decide a classificação.
-- ============================================================================
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
    case when valor_total >= 3000 then 'completa' else 'complemento' end,
    valor_total,
    pedidos
  from base;
$$;

-- ----------------------------------------------------------------------------
-- fn_seal_compradores: a linha exibida deixa de ser escolhida pelo nome do
-- produto (o critério "eh_quitacao" não separa mais nada) e passa a ser a de
-- MAIOR valor cobrado — que é a compra que define o aluno. Empate resolve por
-- ter UTM e depois pela mais recente, como antes.
-- ----------------------------------------------------------------------------
drop function if exists mkt_wep.fn_seal_compradores(date, date);
create function mkt_wep.fn_seal_compradores(
  p_from date default null,
  p_to date default null
)
returns table (
  email        text,
  nome         text,
  situacao     text,
  data         date,
  hora         time,
  utm_source   text,
  utm_campaign text,
  utm_medium   text,
  utm_content  text,
  utm_term     text,
  utm_pagina   text
)
language sql
stable
as $$
  with seal_rows as (
    select
      lower(btrim(email)) as email,
      nome_completo, data, hora,
      last_utm_source, last_utm_campaign, last_utm_medium,
      last_utm_content, last_utm_term, last_utm_pagina,
      coalesce(
        nullif(replace(replace(valor_cobrado, '.', ''), ',', '.'), '')::numeric, 0
      ) as valor,
      (last_utm_campaign is not null and btrim(last_utm_campaign) <> '') as tem_utm
    from core.vendas_pagarme
    where status = 'paid'
      and produto ilike '%seal%'
      and email is not null and btrim(email) <> ''
      and (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
  ),
  melhor as (
    select distinct on (email)
      email, nome_completo, data, hora,
      last_utm_source, last_utm_campaign, last_utm_medium,
      last_utm_content, last_utm_term, last_utm_pagina
    from seal_rows
    order by email, valor desc, tem_utm desc, data desc nulls last, hora desc nulls last
  )
  select
    m.email,
    nullif(btrim(m.nome_completo), '') as nome,
    a.situacao,
    m.data,
    m.hora,
    m.last_utm_source, m.last_utm_campaign, m.last_utm_medium,
    m.last_utm_content, m.last_utm_term, m.last_utm_pagina
  from melhor m
  join mkt_wep.fn_seal_alunos(p_from, p_to) a on a.email = m.email
  order by a.situacao, m.data desc nulls last;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) A nova distribuição no período do SEAL. Compare com o que o painel
--     mostrava antes (7 quitaram / 0 reserva) — deve virar 2 completas e
--     5 complementos, com o mesmo total de alunos:
select situacao, alunos, valor_total
  from mkt_wep.fn_seal_resumo('2026-07-23', '2026-08-31')
 order by situacao;

-- (b) Aluno a aluno, com o valor que motivou a classificação. Nenhum valor
--     pode estar perto da fronteira de R$ 3.000 — se estiver, vale revisar o
--     limiar com quem define a regra:
select situacao, valor_total, pedidos, email
  from mkt_wep.fn_seal_alunos('2026-07-23', '2026-08-31')
 order by valor_total desc;

-- (c) O total de alunos NÃO pode mudar — a reclassificação move gente de
--     grupo, não cria nem some com ninguém. As duas colunas devem ser iguais:
select
  (select count(*) from mkt_wep.fn_seal_alunos('2026-07-23', '2026-08-31'))    as alunos,
  (select sum(alunos) from mkt_wep.fn_seal_resumo('2026-07-23', '2026-08-31')) as soma_dos_cards;

-- (d) A tabela de compradores tem que ter uma linha por aluno, com a mesma
--     situação da (b) — e nenhuma situação fora do par novo (esperado: só
--     'completa' e 'complemento'):
select situacao, count(*) as linhas
  from mkt_wep.fn_seal_compradores('2026-07-23', '2026-08-31')
 group by situacao
 order by situacao;
