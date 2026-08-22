-- ============================================================================
-- Coluna "Valor pago" na tabela de compradores SEAL.
--
-- A tabela mostrava a situação (completa/complemento) sem mostrar o número que
-- a determina. Com o critério agora sendo o valor (sql/77), esconder o valor
-- deixa a classificação sem como ser conferida a olho.
--
-- O valor exibido é o TOTAL DO ALUNO no período (mesmo número que classifica,
-- vindo da fn_seal_alunos), não o valor da linha mostrada. A diferença importa:
-- a tabela exibe uma linha por aluno — a de maior valor cobrado — mas quem
-- pagou em dois pedidos tem total maior que qualquer linha isolada. O Julio,
-- por exemplo, aparece com a linha de R$ 4.770,93 e total de R$ 5.277,43.
--
-- Por isso `pedidos` também entra no retorno: quando é mais de um, o front
-- avisa. Sem esse aviso o valor pareceria não bater com a linha exibida, e a
-- pessoa lendo iria procurar um bug que não existe.
-- ============================================================================
drop function if exists mkt_wep.fn_seal_compradores(date, date);
create function mkt_wep.fn_seal_compradores(
  p_from date default null,
  p_to date default null
)
returns table (
  email        text,
  nome         text,
  situacao     text,
  valor_pago   numeric,
  pedidos      bigint,
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
    a.valor_total as valor_pago,
    a.pedidos,
    m.data,
    m.hora,
    m.last_utm_source, m.last_utm_campaign, m.last_utm_medium,
    m.last_utm_content, m.last_utm_term, m.last_utm_pagina
  from melhor m
  join mkt_wep.fn_seal_alunos(p_from, p_to) a on a.email = m.email
  order by a.situacao, a.valor_total desc, m.data desc nulls last;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) A tabela agora mostra o valor, e ele TEM que ser coerente com a situação:
--     nenhuma linha 'completa' abaixo de 3.000, nenhuma 'complemento' acima
--     (esperado: 0 linhas):
select email, situacao, valor_pago
  from mkt_wep.fn_seal_compradores('2026-07-23', '2026-08-31')
 where (situacao = 'completa'    and valor_pago <  3000)
    or (situacao = 'complemento' and valor_pago >= 3000);

-- (b) O valor da tabela tem que ser o MESMO da fn_seal_alunos, aluno a aluno
--     (esperado: 0 linhas):
select c.email, c.valor_pago, a.valor_total
  from mkt_wep.fn_seal_compradores('2026-07-23', '2026-08-31') c
  join mkt_wep.fn_seal_alunos('2026-07-23', '2026-08-31') a on a.email = c.email
 where c.valor_pago is distinct from a.valor_total;

-- (c) A soma da coluna tem que fechar com o card Faturamento SEAL:
select sum(valor_pago) as faturamento_seal
  from mkt_wep.fn_seal_compradores('2026-07-23', '2026-08-31');

-- (d) Quem tem mais de um pedido — são os que o front marca, porque o total
--     não bate com nenhuma linha isolada:
select email, situacao, valor_pago, pedidos
  from mkt_wep.fn_seal_compradores('2026-07-23', '2026-08-31')
 where pedidos > 1
 order by valor_pago desc;
