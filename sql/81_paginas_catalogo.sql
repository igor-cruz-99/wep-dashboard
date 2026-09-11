-- ============================================================================
-- Seção "WEP – Páginas": catálogo das LPs + função que junta cada uma com o
-- desempenho no período. É o equivalente da galeria de anúncios, só que por
-- página: a head visível no card, o print da hero ao clicar, e os números.
--
-- POR QUE UMA TABELA À MÃO, SEM n8n: são 8 páginas por edição e elas mudam
-- pouco. Um workflow para isso seria mais uma peça para quebrar em silêncio.
-- Página nova ou head alterada: edite o INSERT abaixo e rode de novo — ele é
-- idempotente (on conflict ... do update).
--
-- POR QUE LP, VARIANTE E SINGLE SHOT EM COLUNAS, E NÃO EXTRAÍDOS DO SLUG: a
-- nomenclatura das LPs já mudou quatro vezes neste projeto, e toda regra que
-- lia significado do texto do nome acabou quebrando (sql/74, sql/80). Aqui o
-- significado é declarado, não adivinhado.
--
-- `variante` é a HEADLINE testada (h1/h2/h3), que é o que se quer comparar:
-- lp01-h1-v1 e lp01-h1-wepset26-ss usam a mesma head, então as duas são "h1".
-- `single_shot` marca o sufixo -ss — são as páginas cujo topo diz "NÃO FECHE
-- ESSA PÁGINA OU VAI PERDER A OFERTA EXCLUSIVA".
--
-- `hero_url` nasce nulo e é preenchido pelo script de captura da hero. O
-- INSERT abaixo NÃO sobrescreve esse campo ao ser re-executado — senão cada
-- ajuste de head apagaria os prints já tirados.
--
-- A `head` é o texto PUBLICADO, conferido em 10/09/26 pelo textContent do h1 —
-- com erro e tudo, de propósito: o card mostra o que está no ar, e é assim que
-- o erro fica visível até ser corrigido na página. Dois erros estão no ar:
--   lp01-h3: "renda,sem" — no HTML é "renda,</span>sem"; o fim do span não
--            põe espaço, então o lead lê as duas palavras coladas;
--   lp02-h3: "Patrimonial e. adicionar".
-- Uma primeira conferência limpou o HTML trocando tag por espaço, inventou o
-- espaço depois de "renda," e concluiu que o erro era só da planilha. Não era:
-- a planilha estava certa. Para conferir texto de página, use textContent do
-- DOM, nunca regex sobre o HTML.
--
-- `pagina` é o slug no MESMO formato da vw_pagina_resumo (barra na frente, sem
-- barra no fim, minúsculo), para o cruzamento com page views e vendas ser um
-- igual simples.
-- ============================================================================
create table if not exists mkt_wep.paginas_catalogo (
  pagina        text primary key,
  tag           text        not null,
  lp            text        not null,
  variante      text        not null,
  single_shot   boolean     not null default false,
  head          text        not null,
  link          text        not null,
  hero_url      text,
  ativa         boolean     not null default true,
  atualizado_em timestamptz not null default now()
);

-- Só o porteiro (service_role) lê esta tabela, e ele ignora RLS. Ligar sem
-- política nenhuma fecha a porta para qualquer outra chave, sem custo.
alter table mkt_wep.paginas_catalogo enable row level security;

-- ── Catálogo WEPSET26 ───────────────────────────────────────────────────────
insert into mkt_wep.paginas_catalogo (pagina, tag, lp, variante, single_shot, head, link) values
  ('/workshop-estrategista-patrimonial-lp01-h1-v1-wepset26', 'WEPSET26', 'lp01', 'h1', false,
   'Conheça a profissão que pode adicionar de 10 a 30 mil por mês à sua renda, e que tem muito mais demanda do que profissionais para atender no Brasil.',
   'https://lp.quartavia.com.br/workshop-estrategista-patrimonial-lp01-h1-v1-wepset26/'),
  ('/workshop-estrategista-patrimonial-lp01-h2-wepset26', 'WEPSET26', 'lp01', 'h2', false,
   'Milhões de famílias de alta renda no Brasil ganham bem e não têm ninguém de confiança para orientar o próprio dinheiro. Você pode ser essa pessoa, e ser remunerado por isso.',
   'https://lp.quartavia.com.br/workshop-estrategista-patrimonial-lp01-h2-wepset26/'),
  ('/workshop-estrategista-patrimonial-lp01-h3-wepset26', 'WEPSET26', 'lp01', 'h3', false,
   'Em 2 dias, aprenda o método para se tornar um Estrategista Patrimonial e adicionar de 10 a 30 mil por mês à sua renda,sem precisar largar o que você faz hoje.',
   'https://lp.quartavia.com.br/workshop-estrategista-patrimonial-lp01-h3-wepset26/'),
  ('/workshop-estrategista-patrimonial-lp01-h1-wepset26-ss', 'WEPSET26', 'lp01', 'h1', true,
   'Conheça a profissão que pode adicionar de 10 a 30 mil por mês à sua renda, e que tem muito mais demanda do que profissionais para atender no Brasil.',
   'https://lp.quartavia.com.br/workshop-estrategista-patrimonial-lp01-h1-wepset26-ss/'),
  ('/workshop-estrategista-patrimonial-lp02-h1-wepset26', 'WEPSET26', 'lp02', 'h1', false,
   'Tenha o mesmo nível de remuneração de um Médico sem precisar de anos de estudo.',
   'https://lp.quartavia.com.br/workshop-estrategista-patrimonial-lp02-h1-wepset26/'),
  ('/workshop-estrategista-patrimonial-lp02-h2-wepset26', 'WEPSET26', 'lp02', 'h2', false,
   'Milhões de famílias de alta renda no Brasil ganham bem e não têm ninguém de confiança para orientar o próprio dinheiro. Você pode ser essa pessoa e ser remunerado por isso.',
   'https://lp.quartavia.com.br/workshop-estrategista-patrimonial-lp02-h2-wepset26/'),
  ('/workshop-estrategista-patrimonial-lp02-h3-wepset26', 'WEPSET26', 'lp02', 'h3', false,
   'Em 2 dias, aprenda o método para se tornar um Estrategista Patrimonial e. adicionar de 10 a 30 mil por mês à sua renda, sem precisar largar o que você faz hoje.',
   'https://lp.quartavia.com.br/workshop-estrategista-patrimonial-lp02-h3-wepset26/'),
  ('/workshop-estrategista-patrimonial-lp02-h1-wepset26-ss', 'WEPSET26', 'lp02', 'h1', true,
   'Tenha o mesmo nível de remuneração de um Médico sem precisar de anos de estudo.',
   'https://lp.quartavia.com.br/workshop-estrategista-patrimonial-lp02-h1-wepset26-ss/')
on conflict (pagina) do update set
  tag           = excluded.tag,
  lp            = excluded.lp,
  variante      = excluded.variante,
  single_shot   = excluded.single_shot,
  head          = excluded.head,
  link          = excluded.link,
  ativa         = true,
  atualizado_em = now();
  -- hero_url fica de fora de propósito: re-rodar não apaga o print.

-- ── Função da seção ─────────────────────────────────────────────────────────
-- Parte do CATÁLOGO (left join), não das métricas: página sem nenhuma visita
-- no período continua aparecendo, zerada. Numa seção cujo objetivo é comparar
-- headlines, a variante que não recebeu tráfego é informação, não ruído.
drop function if exists mkt_wep.fn_paginas_galeria(text, date, date);
create function mkt_wep.fn_paginas_galeria(
  p_tag  text default null,
  p_from date default null,
  p_to   date default null
)
returns table (
  pagina          text,
  tag             text,
  lp              text,
  variante        text,
  single_shot     boolean,
  head            text,
  link            text,
  hero_url        text,
  page_views      bigint,
  checkouts       bigint,
  vendas          bigint,
  visita_checkout numeric,
  visita_venda    numeric,
  checkout_venda  numeric
)
language sql
stable
as $$
  with m as (
    select r.pagina,
           sum(r.page_views)::bigint as pv,
           sum(r.checkouts)::bigint  as ck,
           sum(r.vendas)::bigint     as vd
      from mkt_wep.vw_pagina_resumo r
     where (p_from is null or r.data >= p_from)
       and (p_to   is null or r.data <= p_to)
     group by r.pagina
  )
  select c.pagina, c.tag, c.lp, c.variante, c.single_shot, c.head, c.link, c.hero_url,
         coalesce(m.pv, 0),
         coalesce(m.ck, 0),
         coalesce(m.vd, 0),
         case when coalesce(m.pv, 0) > 0 then round(m.ck::numeric / m.pv * 100, 2) else 0 end,
         case when coalesce(m.pv, 0) > 0 then round(m.vd::numeric / m.pv * 100, 2) else 0 end,
         case when coalesce(m.ck, 0) > 0 then round(m.vd::numeric / m.ck * 100, 2) else 0 end
    from mkt_wep.paginas_catalogo c
    left join m on m.pagina = c.pagina
   where c.ativa
     and (p_tag is null or c.tag = p_tag)
   order by c.lp, c.single_shot, c.variante;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) As 8 páginas no catálogo:
select lp, variante, single_shot, pagina
  from mkt_wep.paginas_catalogo
 order by lp, single_shot, variante;

-- (b) O TESTE QUE IMPORTA: todo slug do catálogo tem que existir no GA4. Uma
--     linha aqui é slug digitado errado — a página apareceria sempre zerada e
--     ninguém saberia por quê (esperado: 0 linhas):
select c.pagina as slug_sem_nenhuma_visita_no_ga4
  from mkt_wep.paginas_catalogo c
 where not exists (
   select 1 from mkt_wep.vw_paginas_diario d where d.pagina = c.pagina
 );

-- (c) O caminho inverso: página do WEPSET26 que o GA4 registrou e que ficou
--     FORA do catálogo (esperado: 0 linhas):
select distinct d.pagina as pagina_no_ga4_fora_do_catalogo
  from mkt_wep.vw_paginas_diario d
 where d.pagina ilike '%wepset26%'
   and not exists (select 1 from mkt_wep.paginas_catalogo c where c.pagina = d.pagina);

-- (d) O que a seção vai mostrar no período da edição:
select lp, variante, single_shot, page_views, checkouts, vendas,
       visita_checkout, visita_venda, left(head, 60) as head
  from mkt_wep.fn_paginas_galeria('WEPSET26', '2026-09-10', '2026-09-20');
