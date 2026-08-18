-- ============================================================================
-- Criativos com extensão de arquivo no nome não achavam o anúncio.
--
-- A planilha às vezes traz o nome do anúncio com a extensão colada:
--   planilha (criativos_drive.ad_name): seal_ad_115_..._st.mp4
--   Meta     (dim_anuncios.anuncio)   : seal_ad_115_..._st
--
-- Como todo o casamento é por nome exato, esses criativos ficam invisíveis:
-- não entram na fila de resolução de fileId, não entram na fila de download e
-- o popup mostra "sem preview" mesmo com o arquivo existindo no Drive.
-- Verificado nos seal_ad_115, 116 e 117 — todos na campanha
-- ls-WEP-WEPAGO26-captacao-vendas-auto-q-P04-rmkt-singleshot.
--
-- 30 criativos do catálogo têm extensão no nome. Alguns casam mesmo assim
-- (quando o anúncio foi subido na Meta com o nome do arquivo, extensão
-- inclusive), mas depender disso é sorte.
--
-- Correção: uma função de normalização usada nos dois lados de todo casamento
-- por nome. Ela só tira a extensão do FIM e passa para minúsculas — não mexe em
-- pontos no meio do nome (ex.: "seal_ad_106.1_gb_topo" continua intacto).
-- ============================================================================

create or replace function mkt_wep.norm_ad_name(p text)
returns text
language sql
immutable
as $$
  select lower(
    regexp_replace(btrim(coalesce(p, '')), '\.(mp4|mov|m4v|avi|png|jpe?g|gif|webp)$', '', 'i')
  );
$$;

comment on function mkt_wep.norm_ad_name(text) is
  'Normaliza nome de anuncio para casamento: minusculas e sem extensao de arquivo no fim. Usar nos DOIS lados de qualquer join por nome entre criativos_drive e dim_anuncios.';

-- ── Fila de resolução de fileId ────────────────────────────────────────────
drop function if exists mkt_wep.fn_criativos_sem_fileid(int);
create function mkt_wep.fn_criativos_sem_fileid(p_limit int default 20)
returns table (
  ad_name         text,
  drive_folder_id text,
  arquivo_feed    text,
  arquivo_story   text
)
language sql
stable
as $$
  select c.ad_name, c.drive_folder_id, c.arquivo_feed, c.arquivo_story
    from mkt_wep.criativos_drive c
   where c.drive_feed_id is null
     and c.drive_story_id is null
     and c.drive_folder_id is not null
     and coalesce(c.arquivo_feed, c.arquivo_story) is not null
     and exists (
       select 1 from mkt_wep.dim_anuncios d
        where mkt_wep.norm_ad_name(d.anuncio) = mkt_wep.norm_ad_name(c.ad_name)
          and d.campanha ilike '%wep%'
     )
   order by c.ad_name
   limit p_limit;
$$;

-- ── Fila de download ───────────────────────────────────────────────────────
drop function if exists mkt_wep.fn_criativos_drive_pendentes(int);
create function mkt_wep.fn_criativos_drive_pendentes(p_limit int default 10)
returns table (
  ad_name       text,
  tipo          text,
  drive_file_id text
)
language sql
stable
as $$
  select c.ad_name, c.tipo, coalesce(c.drive_feed_id, c.drive_story_id)
    from mkt_wep.criativos_drive c
   where c.synced_at is null
     and coalesce(c.drive_feed_id, c.drive_story_id) is not null
     and exists (
       select 1 from mkt_wep.dim_anuncios d
        where mkt_wep.norm_ad_name(d.anuncio) = mkt_wep.norm_ad_name(c.ad_name)
          and d.campanha ilike '%wep%'
     )
   order by c.ad_name
   limit p_limit;
$$;

-- ── Popup de preview ───────────────────────────────────────────────────────
drop function if exists mkt_wep.fn_ad_thumbnail(text);
create function mkt_wep.fn_ad_thumbnail(p_ad_id text)
returns table (
  ad_id        text,
  ad_name      text,
  url          text,
  video_url    text,
  sincronizado boolean
)
language sql
stable
as $$
  select
    d.ad_id::text,
    d.anuncio::text,
    coalesce(c.storage_url, t.storage_url, t.image_url, t.thumbnail_url)::text,
    coalesce(c.storage_video_url, t.storage_video_url)::text,
    (c.synced_at is not null or t.synced_at is not null)
  from mkt_wep.dim_anuncios d
  left join mkt_wep.criativos_drive c
    on mkt_wep.norm_ad_name(c.ad_name) = mkt_wep.norm_ad_name(d.anuncio)
  left join core.ads_thumbnails t
    on t.ad_id::text = d.ad_id::text
  where d.ad_id::text = p_ad_id
  limit 1;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Os três que motivaram o ajuste devem aparecer na fila de resolução:
select ad_name, drive_folder_id, arquivo_feed
  from mkt_wep.fn_criativos_sem_fileid(500)
 where ad_name ilike '%seal_ad_11%';

-- (b) Quantos criativos passam a ser reconhecidos (antes: 100 com fileId):
select count(*) as criativos_veiculados_em_wep
  from mkt_wep.criativos_drive c
 where exists (
   select 1 from mkt_wep.dim_anuncios d
    where mkt_wep.norm_ad_name(d.anuncio) = mkt_wep.norm_ad_name(c.ad_name)
      and d.campanha ilike '%wep%'
 );

-- (c) ad_ids que passam a ter preview (antes: 163):
select count(*) as ad_ids_cobertos
  from mkt_wep.dim_anuncios d
 where d.campanha ilike '%wep%'
   and exists (
     select 1 from mkt_wep.criativos_drive c
      where mkt_wep.norm_ad_name(c.ad_name) = mkt_wep.norm_ad_name(d.anuncio)
        and (c.storage_url is not null or c.storage_video_url is not null)
   );

-- (d) Tamanho das duas filas depois do ajuste:
select
  (select count(*) from mkt_wep.fn_criativos_sem_fileid(500)) as fila_resolver_fileid,
  (select count(*) from mkt_wep.fn_criativos_drive_pendentes(500)) as fila_download;
