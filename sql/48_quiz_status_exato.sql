-- ============================================================================
-- CORREÇÃO: status pode ser "Não comprou", que CONTÉM a palavra "comprou"
-- como substring — o filtro ilike '%comprou%' (sql/47) contava as duas
-- categorias como venda. Troca pra igualdade exata (case-insensitive).
-- ============================================================================
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
    count(*) filter (where lower(btrim(status)) = 'comprou') as vendas
  from mkt_wep.wep_quiz
  where (p_tag  is null or tag = p_tag)
    and (p_from is null or data >= p_from)
    and (p_to   is null or data <= p_to);
$$;
