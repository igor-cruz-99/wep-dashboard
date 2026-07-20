-- ============================================================================
-- WEP DASHBOARD — Views do schema mkt_wep
-- Rodar no SQL Editor do Supabase.
--
-- Arquitetura:
--   core.ads_metrics / core.paginas_ga4  (fontes brutas, intocadas)
--   mkt_wep.wep_*                        (tabelas do lançamento)
--   mkt_wep.dim_* / vw_*                 (estas views — o front só lê daqui)
--
-- Regras acordadas:
--   • Ads:  campanha ILIKE '%wep%'
--   • GA4:  caminho_da_pagina ILIKE '%wep%'
--   • Tag → ads/GA4: pela janela de datas da tag (inicio_cap..final_cap)
--
-- ⚠️ AJUSTAR ANTES DE RODAR (marcados com TODO):
--   1. Status que conta como venda válida / checkout válido
--   2. Fórmulas de Hook/Hold/Body (deixei as convenções mais comuns)
--   3. Regra de "qualificado" na pesquisa (depende do json respostas)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Normalizador de página: minúsculas, sem protocolo/domínio, sem query
--    string, sem barra final.  'https://Site.com/WEP/Inscricao/?x=1' → '/wep/inscricao'
-- ----------------------------------------------------------------------------
create or replace function mkt_wep.norm_pagina(p text)
returns text
language sql
immutable
as $$
  select rtrim(
    regexp_replace(
      regexp_replace(lower(coalesce(p, '')), '^https?://[^/]+', ''),
      '[?#].*$', ''
    ),
    '/'
  );
$$;

-- ----------------------------------------------------------------------------
-- 1. DIMENSÃO: anúncios únicos do WEP (1 linha por anúncio)
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.dim_anuncios as
select distinct
  ad_id,
  campanha,
  conjunto,
  anuncio
from core.ads_metrics
where campanha ilike '%wep%';

-- ----------------------------------------------------------------------------
-- 2. FATO: métricas de ads por dia (funil, investimento/dia, análise tráfego)
--    Hook/Hold/Body já calculados por linha.  -- TODO: confirmar fórmulas
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.vw_ads_diario as
select
  data,
  campanha,
  conjunto,
  anuncio,
  ad_id,
  gasto,
  alcance,
  impressoes,
  cliques,
  link_cliques,
  landing_page_views,
  video_plays,
  video_3s,
  "video_25%"  as video_25p,
  "video_50%"  as video_50p,
  "video_75%"  as video_75p,
  "video_95%"  as video_95p,
  "video_100%" as video_100p,
  -- Hook: % das impressões que assistiram 3s (gancho)
  case when impressoes > 0
       then round(100.0 * video_3s / impressoes, 1) else 0 end as hook_pct,
  -- Hold: % de quem viu 3s que chegou a 25% (retenção após o gancho)
  case when video_3s > 0
       then round(100.0 * "video_25%" / video_3s, 1) else 0 end as hold_pct,
  -- Body (retenção): % das impressões que chegaram a 50% do vídeo
  case when impressoes > 0
       then round(100.0 * "video_50%" / impressoes, 1) else 0 end as body_pct
from core.ads_metrics
where campanha ilike '%wep%';

-- ----------------------------------------------------------------------------
-- 3. FATO: vendas com anúncio atribuído via UTM
--    (atenção: a coluna real é utm_campaing — typo existente na tabela)
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.vw_vendas as
select
  v.id,
  v.tag,
  v.data,
  v.hora,
  v.status,
  v.produto,
  v.valor,
  v.parcelas,
  v.estado,
  v.tel_8d,
  mkt_wep.norm_pagina(v.utm_pagina) as pagina,
  d.ad_id,
  d.campanha,
  d.conjunto,
  d.anuncio,
  -- Venda válida = status 'APPROVED' (case-insensitive por segurança)
  (upper(coalesce(v.status, '')) = 'APPROVED') as venda_valida
from mkt_wep.wep_vendas v
left join mkt_wep.dim_anuncios d
  on v.utm_campaing = d.campanha
 and v.utm_content  = d.anuncio;

-- ----------------------------------------------------------------------------
-- 4. FATO: checkouts com anúncio atribuído (join exato por utm_id = ad_id,
--    com fallback por nome quando utm_id vier vazio).
--    Todo registro conta como um checkout — a compra aprovada mora em wep_vendas.
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.vw_checkouts as
select
  c.id,
  c.tag,
  c.data,
  c.hora,
  c.tel_8d,
  mkt_wep.norm_pagina(c.utm_pagina) as pagina,
  coalesce(di.ad_id, dn.ad_id)       as ad_id,
  coalesce(di.campanha, dn.campanha) as campanha,
  coalesce(di.conjunto, dn.conjunto) as conjunto,
  coalesce(di.anuncio, dn.anuncio)   as anuncio
from mkt_wep.wep_checkout c
left join mkt_wep.dim_anuncios di
  on c.utm_id = di.ad_id
left join mkt_wep.dim_anuncios dn
  on c.utm_campaign = dn.campanha
 and c.utm_content  = dn.anuncio;

-- ----------------------------------------------------------------------------
-- 5. FATO: page views do GA4 (somente páginas WEP, caminho normalizado)
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.vw_paginas_diario as
select
  data,
  mkt_wep.norm_pagina(caminho_da_pagina) as pagina,
  sum(visualizacoes)   as page_views,
  sum(usuarios_unicos) as usuarios_unicos
from core.paginas_ga4
where caminho_da_pagina ilike '%wep%'
group by data, mkt_wep.norm_pagina(caminho_da_pagina);

-- ----------------------------------------------------------------------------
-- 6. FATO: entradas no grupo por dia
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.vw_grupos_diario as
select
  tag,
  data_entrada as data,
  count(*)     as entradas,
  count(data_saida) as saidas_registradas
from mkt_wep.wep_grupos
group by tag, data_entrada;

-- ----------------------------------------------------------------------------
-- 7. FATO: pesquisas por dia
--    Qualificado = coluna 'qualificacao' (texto '1'/'0') já vem pronta da
--    automação: '1' quando a renda declarada é >= 10 mil.
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.vw_pesquisa_diario as
select
  tag,
  data,
  count(*) as pesquisas,
  count(*) filter (where qualificacao = '1') as qualificados
from mkt_wep.wep_pesquisa
group by tag, data;

-- ----------------------------------------------------------------------------
-- 8. RESUMO: tabela "Páginas" do painel (GA4 + checkout + vendas + pesquisa
--    cruzados pela página normalizada, por dia — o front soma o período)
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.vw_pagina_resumo as
with ga4 as (
  select pagina, data, sum(page_views) as page_views
  from mkt_wep.vw_paginas_diario
  group by pagina, data
),
cks as (
  select pagina, data, count(*) as checkouts
  from mkt_wep.vw_checkouts
  group by pagina, data
),
vds as (
  select pagina, data, count(*) filter (where venda_valida) as vendas
  from mkt_wep.vw_vendas
  group by pagina, data
)
select
  coalesce(g.pagina, c.pagina, v.pagina) as pagina,
  coalesce(g.data, c.data, v.data)       as data,
  coalesce(g.page_views, 0)              as page_views,
  coalesce(c.checkouts, 0)               as checkouts,
  coalesce(v.vendas, 0)                  as vendas
from ga4 g
full join cks c on c.pagina = g.pagina and c.data = g.data
full join vds v on v.pagina = coalesce(g.pagina, c.pagina)
              and v.data   = coalesce(g.data, c.data);

-- ----------------------------------------------------------------------------
-- 8b. Tags via view (wep_tags é tabela e tem RLS; a view roda como owner e
--     ignora RLS, deixando o anon ler as tags e metas — igual às demais views).
-- ----------------------------------------------------------------------------
create or replace view mkt_wep.vw_tags as
select * from mkt_wep.wep_tags;

-- ----------------------------------------------------------------------------
-- 9. PERMISSÕES: expor o schema mkt_wep pra API ler as views
--    (Depois disso, marque mkt_wep em Settings → API → Exposed schemas)
-- ----------------------------------------------------------------------------
grant usage on schema mkt_wep to anon, authenticated;
grant select on all tables in schema mkt_wep to anon, authenticated;
alter default privileges in schema mkt_wep
  grant select on tables to anon, authenticated;
