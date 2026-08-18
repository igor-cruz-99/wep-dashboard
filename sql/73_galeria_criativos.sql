-- ============================================================================
-- Galeria de criativos: uma tela mostrando a PEÇA junto do seu desempenho.
--
-- A tabela de tráfego responde "qual campanha performa"; a galeria responde
-- "qual criativo performa" — e é uma pergunta diferente. Exemplo real do
-- período: seal_ad_0044 gastou um terço do seal_ad_0022 e vendeu quase o mesmo
-- (CAC 452 contra 1.129). Na tabela isso fica diluído entre campanhas.
--
-- Um card por CRIATIVO (nome), somando todas as campanhas onde a peça rodou.
-- Só entram os que têm mídia sincronizada E gasto no período — a galeria
-- acompanha o período escolhido, como o resto do painel.
--
-- O casamento com o catálogo usa norm_ad_name (sql/72), que ignora extensão de
-- arquivo no fim do nome: a planilha às vezes traz "..._st.mp4" e a Meta não.
-- ============================================================================
drop function if exists mkt_wep.fn_criativos_galeria(date, date, text[]);
create function mkt_wep.fn_criativos_galeria(
  p_from date default null,
  p_to date default null,
  p_excluir text[] default null
)
returns table (
  ad_name           text,
  tipo              text,
  storage_url       text,
  storage_video_url text,
  investimento      numeric,
  vendas            bigint,
  checkouts         bigint,
  cac               numeric,
  campanhas         bigint
)
language sql
stable
as $$
  with gasto as (
    -- Métricas por nome de anúncio, somando as campanhas em que rodou.
    select
      mkt_wep.norm_ad_name(a.anuncio) as chave,
      sum(a.gasto)                    as investimento,
      count(distinct a.campanha)      as campanhas
    from mkt_wep.vw_ads_diario a
    where (p_from is null or a.data >= p_from)
      and (p_to   is null or a.data <= p_to)
      and a.campanha ilike '%wep%'
      and a.anuncio is not null
      and (p_excluir is null or not (a.campanha = any(p_excluir)))
    group by 1
    having sum(a.gasto) > 0
  ),
  vds as (
    select mkt_wep.norm_ad_name(anuncio) as chave,
           count(*) filter (where venda_valida) as vendas
    from mkt_wep.vw_vendas
    where (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
      and anuncio is not null
    group by 1
  ),
  cks as (
    select mkt_wep.norm_ad_name(anuncio) as chave,
           count(*) as checkouts
    from mkt_wep.vw_checkouts
    where (p_from is null or data >= p_from)
      and (p_to   is null or data <= p_to)
      and anuncio is not null
    group by 1
  ),
  midia as (
    -- Um criativo por chave: se houver mais de uma linha do catálogo com o
    -- mesmo nome normalizado, fica a que tem mídia.
    select distinct on (mkt_wep.norm_ad_name(c.ad_name))
      mkt_wep.norm_ad_name(c.ad_name) as chave,
      c.ad_name,
      c.tipo,
      c.storage_url,
      c.storage_video_url
    from mkt_wep.criativos_drive c
    where c.storage_url is not null or c.storage_video_url is not null
    order by mkt_wep.norm_ad_name(c.ad_name), c.storage_video_url nulls last, c.ad_name
  )
  select
    m.ad_name,
    m.tipo,
    m.storage_url,
    m.storage_video_url,
    round(g.investimento, 2)                as investimento,
    coalesce(v.vendas, 0)                   as vendas,
    coalesce(k.checkouts, 0)                as checkouts,
    case when coalesce(v.vendas, 0) > 0
         then round(g.investimento / v.vendas, 2)
         else 0 end                         as cac,
    g.campanhas
  from gasto g
  join midia m on m.chave = g.chave
  left join vds v on v.chave = g.chave
  left join cks k on k.chave = g.chave
  order by g.investimento desc;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Quantos criativos aparecem no período do Padrão (esperado: ~69):
select count(*) as criativos from mkt_wep.fn_criativos_galeria('2026-07-31', '2026-08-21');

-- (b) Os 5 que mais gastaram, com desempenho:
select ad_name, tipo, investimento, vendas, cac, campanhas
  from mkt_wep.fn_criativos_galeria('2026-07-31', '2026-08-21')
 limit 5;

-- (c) Todos devem ter mídia — a galeria não mostra card vazio (esperado: 0):
select count(*) as sem_midia
  from mkt_wep.fn_criativos_galeria('2026-07-31', '2026-08-21')
 where storage_url is null and storage_video_url is null;

-- (d) O total de investimento aqui é MENOR que o da tabela de tráfego, e isso
--     é esperado: só entram criativos com mídia sincronizada. A diferença é o
--     que ainda não passou pelo sync do Drive.
select
  (select round(sum(investimento), 2) from mkt_wep.fn_criativos_galeria('2026-07-31', '2026-08-21')) as galeria,
  (select round(sum(investimento), 2) from mkt_wep.fn_trafego('2026-07-31', '2026-08-21') where nivel = 'anuncio') as trafego_total;
