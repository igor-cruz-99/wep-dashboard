-- ============================================================================
-- Bloco "Vendas / Por compradores": uma linha por comprador, com as UTMs
-- inteiras, a página e a oferta.
--
-- Por que existe: os blocos de venda hoje são todos agregados (funil, tabela
-- por página, galeria por criativo). Quando um número chama atenção — as 11
-- vendas de R$ 1 do dia 18, por exemplo — não há onde olhar linha a linha para
-- entender de onde vieram. Este bloco é essa lupa.
--
-- Decisões:
--
--   1. Só venda APPROVED, o mesmo critério de "venda válida" do resto do
--      painel. Assim a contagem de linhas bate com a etapa Vendas do funil e
--      com a coluna Vendas da tabela por página — se divergir, é bug, e isso
--      é proposital.
--
--   2. A página sai normalizada pela MESMA cadeia da tabela de desempenho
--      (norm_pagina -> norm_pagina_venda). O comprador aparece com o slug
--      '/workshop-...-lp04-h1-v5-wep', não com o nome cru da UTM, para dar
--      para cruzar as duas tabelas a olho. Quem não tiver UTM de página cai
--      em null e o front mostra travessão.
--
--   3. A oferta é o valor pago. Não existe campo de oferta na origem: o que
--      distingue "R$ 27 cheio", "R$ 13,50 promocional" e "R$ 1 reativação de
--      ex-aluno" é só o valor. Vai cru, sem rótulo, porque a regra de negócio
--      de qual valor é qual oferta ainda não está fechada.
--
--   4. p_origem e p_excluir seguem o funil, para o bloco obedecer aos mesmos
--      filtros do topo do painel e não contar uma campanha que o resto da tela
--      está escondendo.
--
-- Dado pessoal: nome e email trafegam só pelo /api/dashboard, que já exige
-- token válido de funcionário. Nada de novo em termos de exposição — a tabela
-- de compradores do SEAL já mostra os mesmos campos.
-- ============================================================================
drop function if exists mkt_wep.fn_vendas_compradores(text, date, date, text, text[]);
create function mkt_wep.fn_vendas_compradores(
  p_tag text default null,
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_excluir text[] default null
)
returns table (
  id            bigint,
  nome          text,
  email         text,
  data          date,
  hora          time,
  valor         numeric,
  produto       text,
  pagina        text,
  utm_source    text,
  utm_medium    text,
  utm_campaign  text,
  utm_term      text,
  utm_content   text
)
language sql
stable
as $$
  select
    v.id::bigint,
    nullif(btrim(coalesce(v.nome_completo, '')), '')  as nome,
    nullif(btrim(coalesce(v.email, '')), '')          as email,
    v.data,
    v.hora,
    v.valor,
    nullif(btrim(coalesce(v.produto, '')), '')        as produto,
    -- mesma cadeia da vw_pagina_resumo, para o slug bater com a tabela de cima
    nullif(mkt_wep.norm_pagina_venda(mkt_wep.norm_pagina(v.utm_pagina)), '') as pagina,
    nullif(btrim(coalesce(v.utm_source, '')), '')     as utm_source,
    nullif(btrim(coalesce(v.utm_medium, '')), '')     as utm_medium,
    nullif(btrim(coalesce(v.utm_campaing, '')), '')   as utm_campaign,  -- typo na origem
    nullif(btrim(coalesce(v.utm_term, '')), '')       as utm_term,
    nullif(btrim(coalesce(v.utm_content, '')), '')    as utm_content
  from mkt_wep.wep_vendas v
  where upper(coalesce(v.status, '')) = 'APPROVED'
    and (p_tag  is null or v.tag = p_tag)
    and (p_from is null or v.data >= p_from)
    and (p_to   is null or v.data <= p_to)
    and (p_origem is null or p_origem = 'todas'
         or (p_origem = 'nativo' and v.utm_pagina = 'Forms_nativo')
         or (p_origem = 'pagina' and coalesce(v.utm_pagina, '') <> 'Forms_nativo'))
    and (p_excluir is null or v.utm_campaing is null
         or not (v.utm_campaing = any(p_excluir)))
  order by v.data desc, v.hora desc nulls last, v.id desc;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) A CONFERÊNCIA QUE IMPORTA: a contagem tem que bater com a etapa Vendas
--     do funil no mesmo período. As duas linhas iguais, qualquer que seja o
--     número — se divergirem, os critérios saíram de sincronia:
select 'compradores' as origem, count(*)::numeric as vendas
  from mkt_wep.fn_vendas_compradores(null, '2026-08-18', '2026-08-19')
union all
select 'funil', valor
  from mkt_wep.fn_funil(null, '2026-08-18', '2026-08-19', null, null, true)
 where etapa = 'Vendas';

-- (b) As ofertas do período, para ver a distribuição de valor — é aqui que as
--     vendas de R$ 1 (reativação de ex-aluno) aparecem separadas das cheias:
select valor, count(*) as vendas
  from mkt_wep.fn_vendas_compradores(null, '2026-08-18', '2026-08-19')
 group by valor
 order by valor;

-- (c) Quantos compradores ficaram sem página e sem campanha — são os que
--     entraram direto no checkout, sem passar por LP:
select count(*) filter (where pagina is null)       as sem_pagina,
       count(*) filter (where utm_campaign is null) as sem_campanha
  from mkt_wep.fn_vendas_compradores(null, '2026-08-18', '2026-08-19');

-- (d) O slug tem que casar com o da tabela de desempenho — estas páginas devem
--     aparecer com o MESMO nome nas duas telas. Compare os nomes, não os
--     números: num dia em curso eles sobem entre uma consulta e outra.
select pagina, count(*) as vendas
  from mkt_wep.fn_vendas_compradores(null, '2026-08-18', '2026-08-19')
 where pagina like '/workshop-estrategista-patrimonial-lp0%'
 group by pagina
 order by pagina;
