-- ============================================================================
-- Leads contados com join ambíguo na fn_trafego.
--
-- O CTE "lds" casa o lead com o anúncio por (campanha, anúncio) — par que NÃO
-- é chave única: 311 dos 1.103 pares do dim_anuncios têm mais de um ad_id, e o
-- pior tem 689. Quando um lead cai num desses, ele é contado uma vez por ad_id.
-- É exatamente a mecânica que fez 1 checkout virar 50 (corrigida no sql/59) e
-- que inflava a tabela de tráfego (sql/60).
--
-- Estado hoje (verificado antes desta migração): 291 leads casam e 291 são
-- contados — nenhum caiu num par ambíguo ainda. Ou seja, o número está certo
-- por sorte, não por construção. Um único lead num anúncio de escala inflaria
-- o total, o CPL e o funil de uma vez.
--
-- Correção: join LATERAL com limit 1, garantindo uma linha por lead.
--
-- LIMITAÇÃO ACEITA CONSCIENTEMENTE: quando o par é ambíguo, os ad_ids podem
-- estar em CONJUNTOS diferentes (208 dos 311 casos). Como o lead não carrega o
-- ad_id — wep_cadastro só tem utm_campaign/utm_content/utm_term, e o utm_term
-- não é ad_id (0 de 292 casaram) — não há como saber de qual conjunto ele veio.
-- O lateral escolhe o primeiro por (conjunto, ad_id), de forma determinística.
-- O total por campanha fica sempre correto; a atribuição a um conjunto
-- específico é aproximada nesses casos. É melhor que a alternativa atual, que
-- conta o mesmo lead em todos os conjuntos.
--
-- Para resolver de vez seria preciso o ad_id na URL de captação (utm_id, como o
-- checkout já faz) — mudança no rastreamento, fora do dashboard.
-- ============================================================================
drop function if exists mkt_wep.fn_trafego(date, date, text, text[]);
create function mkt_wep.fn_trafego(
  p_from date default null,
  p_to date default null,
  p_origem text default null,
  p_excluir text[] default null
)
returns table (
  nivel text,
  campanha text,
  conjunto text,
  anuncio text,
  ad_id text,
  investimento numeric,
  vendas bigint,
  checkouts bigint,
  leads bigint,
  cac numeric,
  hook numeric,
  hold numeric,
  body numeric
)
language sql
stable
as $$
  with ads as (
    select campanha, conjunto, anuncio,
           -- representante do grupo: com N cópias do mesmo criativo, qualquer
           -- ad_id serve para o preview (a mídia é casada por nome). Antes o
           -- ad_id estava no group by e era ele que multiplicava as linhas.
           min(ad_id) as ad_id,
           sum(gasto) as gasto,
           sum(impressoes) as imp,
           sum(video_3s) as v3,
           sum(video_25p) as v25,
           sum(video_50p) as v50
    from mkt_wep.vw_ads_diario
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio))
  ),
  vds as (
    select campanha, conjunto, anuncio,
           count(*) filter (where venda_valida) as vendas
    from mkt_wep.vw_vendas
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio))
  ),
  cks as (
    select campanha, conjunto, anuncio,
           count(*) as checkouts
    from mkt_wep.vw_checkouts
    where (p_from is null or data >= p_from) and (p_to is null or data <= p_to)
    group by grouping sets ((campanha), (campanha, conjunto), (campanha, conjunto, anuncio))
  ),
  lds as (
    -- join LATERAL com limit 1: o par (campanha, anúncio) não é chave única
    -- (311 dos 1.103 pares têm mais de um ad_id, o pior com 689), e o join
    -- direto multiplicava o lead por esse número. Mesmo defeito que fez 1
    -- checkout virar 50 na vw_checkouts (sql/59).
    select d.campanha, d.conjunto, d.anuncio, count(*) as leads
    from mkt_wep.wep_cadastro c
    join lateral (
      select d0.campanha, d0.conjunto, d0.anuncio
        from mkt_wep.dim_anuncios d0
       where d0.campanha = c.utm_campaign
         and d0.anuncio  = c.utm_content
       order by d0.conjunto, d0.ad_id
       limit 1
    ) d on true
    where (p_from is null or c.data >= p_from) and (p_to is null or c.data <= p_to)
    group by grouping sets ((d.campanha), (d.campanha, d.conjunto), (d.campanha, d.conjunto, d.anuncio))
  )
  select
    case
      when ads.anuncio is not null then 'anuncio'
      when ads.conjunto is not null then 'conjunto'
      else 'campanha'
    end as nivel,
    ads.campanha, ads.conjunto, ads.anuncio, ads.ad_id,
    ads.gasto as investimento,
    coalesce(vds.vendas, 0) as vendas,
    coalesce(cks.checkouts, 0) as checkouts,
    coalesce(lds.leads, 0) as leads,
    case when coalesce(vds.vendas,0) > 0 then round(ads.gasto / vds.vendas, 2) else 0 end as cac,
    case when ads.imp > 0 then round(100.0 * ads.v3  / ads.imp, 1) else 0 end as hook,
    case when ads.v3  > 0 then round(100.0 * ads.v25 / ads.v3,  1) else 0 end as hold,
    case when ads.imp > 0 then round(100.0 * ads.v50 / ads.imp, 1) else 0 end as body
  from ads
  left join vds
    on  ads.campanha is not distinct from vds.campanha
    and ads.conjunto is not distinct from vds.conjunto
    and ads.anuncio  is not distinct from vds.anuncio
  left join cks
    on  ads.campanha is not distinct from cks.campanha
    and ads.conjunto is not distinct from cks.conjunto
    and ads.anuncio  is not distinct from cks.anuncio
  left join lds
    on  ads.campanha is not distinct from lds.campanha
    and ads.conjunto is not distinct from lds.conjunto
    and ads.anuncio  is not distinct from lds.anuncio
  where ads.campanha ilike '%wep%'
    and (p_origem is null or p_origem = 'todas'
         or (p_origem = 'nativo' and ads.campanha ilike '%forms-nativo%')
         or (p_origem = 'pagina' and ads.campanha not ilike '%forms-nativo%'))
    and (p_excluir is null or ads.campanha is null or not (ads.campanha = any(p_excluir)))
  order by ads.campanha, ads.conjunto nulls first, ads.anuncio nulls first;
$$;


-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Total de leads NÃO pode mudar hoje (esperado: igual antes e depois,
--     porque nenhum lead está em par ambíguo no momento):
select sum(leads) as leads_nivel_anuncio
  from mkt_wep.fn_trafego(current_date - 30, current_date)
 where nivel = 'anuncio';

-- (b) Confere contra a fonte: quantos leads casam com dim_anuncios nos últimos
--     30 dias (os dois números devem bater):
select count(*) as leads_na_fonte
  from mkt_wep.wep_cadastro c
 where c.data between current_date - 30 and current_date
   and exists (
     select 1 from mkt_wep.dim_anuncios d
      where d.campanha = c.utm_campaign and d.anuncio = c.utm_content
   );

-- (c) Investimento e conversões seguem intactos — só o CTE de leads mudou:
select round(sum(investimento), 2) as investimento,
       sum(checkouts) as checkouts,
       sum(vendas) as vendas
  from mkt_wep.fn_trafego(current_date - 30, current_date)
 where nivel = 'anuncio';
