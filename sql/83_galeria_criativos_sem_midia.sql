-- ============================================================================
-- Galeria de criativos: anúncios SEM mídia também entram.
--
-- A fn_criativos_galeria (sql/76) fazia INNER JOIN com o catálogo de mídia, e
-- anúncio sem imagem/vídeo sincronizado sumia da galeria levando junto o gasto
-- e as vendas dele. O total do topo ("R$ X investidos · N vendas") ficava
-- errado sem aviso nenhum. Medido em 10-20/09 (WEPSET26): a galeria mostrava
-- 3 anúncios e R$ 1.921, enquanto a Meta gastou R$ 5.925 em 10 anúncios.
--
-- Correção: LEFT JOIN. Quem não tem mídia volta com storage_url e
-- storage_video_url nulos (o front mostra "criativo não encontrado"), e o nome
-- vem do próprio anúncio da Meta, já que não há linha no catálogo.
--
-- Mesmo retorno do sql/76, então dá para usar create or replace.
-- ============================================================================
create or replace function mkt_wep.fn_criativos_galeria(
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
  campanhas         bigint,
  alcance           numeric,
  impressoes        numeric,
  cliques           numeric,
  cpm               numeric,
  cpc               numeric,
  ctr               numeric,
  frequencia        numeric
)
language sql
stable
as $$
  with gasto as (
    -- Métricas por nome de anúncio, somando as campanhas em que rodou.
    select
      mkt_wep.norm_ad_name(a.anuncio) as chave,
      -- Nome exibido quando o anúncio não está no catálogo de mídia.
      min(a.anuncio)                  as nome_meta,
      sum(a.gasto)                    as investimento,
      count(distinct a.campanha)      as campanhas,
      coalesce(sum(a.alcance), 0)     as alcance,
      coalesce(sum(a.impressoes), 0)  as impressoes,
      coalesce(sum(a.cliques), 0)     as cliques
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
    coalesce(m.ad_name, g.nome_meta)        as ad_name,
    m.tipo,
    m.storage_url,
    m.storage_video_url,
    round(g.investimento, 2)                as investimento,
    coalesce(v.vendas, 0)                   as vendas,
    coalesce(k.checkouts, 0)                as checkouts,
    case when coalesce(v.vendas, 0) > 0
         then round(g.investimento / v.vendas, 2)
         else 0 end                         as cac,
    g.campanhas,
    g.alcance,
    g.impressoes,
    g.cliques,
    case when g.impressoes > 0
         then round(g.investimento / g.impressoes * 1000, 2)
         else 0 end                         as cpm,
    case when g.cliques > 0
         then round(g.investimento / g.cliques, 2)
         else 0 end                         as cpc,
    case when g.impressoes > 0
         then round(g.cliques::numeric / g.impressoes * 100, 2)
         else 0 end                         as ctr,
    case when g.alcance > 0
         then round(g.impressoes::numeric / g.alcance, 2)
         else 0 end                         as frequencia
  from gasto g
  left join midia m on m.chave = g.chave
  left join vds v on v.chave = g.chave
  left join cks k on k.chave = g.chave
  order by g.investimento desc;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) A galeria soma o gasto inteiro da Meta. As duas colunas devem ser
--     IGUAIS (medido em 10-20/09: 10 anúncios, R$ 5.925,13, 7 sem mídia):
select
  (select count(*) from mkt_wep.fn_criativos_galeria('2026-09-10', '2026-09-20'))              as anuncios,
  (select count(*) from mkt_wep.fn_criativos_galeria('2026-09-10', '2026-09-20')
    where storage_url is null and storage_video_url is null)                                   as sem_midia,
  (select sum(investimento) from mkt_wep.fn_criativos_galeria('2026-09-10', '2026-09-20'))     as gasto_galeria,
  (select round(sum(gasto), 2) from mkt_wep.vw_ads_diario
    where data between '2026-09-10' and '2026-09-20'
      and campanha ilike '%wep%' and anuncio is not null)                                      as gasto_meta;

-- (b) Quais são os anúncios sem mídia (é a lista para sincronizar no Drive):
select ad_name, investimento, vendas
  from mkt_wep.fn_criativos_galeria('2026-09-10', '2026-09-20')
 where storage_url is null and storage_video_url is null;
