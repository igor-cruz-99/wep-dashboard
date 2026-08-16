-- 54_recriar_fn_ad_thumbnail.sql
-- A mkt_wep.fn_ad_thumbnail não existe mais no banco (PostgREST: "Could not find
-- the function mkt_wep.fn_ad_thumbnail(p_ad_id) in the schema cache"), então o
-- popup de preview do anúncio sempre cai no estado "sem preview".
-- Provável: o `drop function` do sql/33 rodou e o `create` seguinte falhou.
--
-- Mesma definição do sql/33, com dois endurecimentos:
--   - alias `t.` em todas as colunas (evita qualquer colisão com os nomes
--     declarados no RETURNS TABLE);
--   - cast explícito nos dois lados da comparação e no retorno, pra não
--     depender do tipo de core.ads_thumbnails.ad_id ser text ou bigint.

drop function if exists mkt_wep.fn_ad_thumbnail(text);

create function mkt_wep.fn_ad_thumbnail(p_ad_id text)
returns table (
  ad_id text,
  ad_name text,
  url text,             -- imagem: storage_url > image_url > thumbnail_url
  video_url text,       -- vídeo: só storage_video_url (a URL da Meta expira rápido)
  sincronizado boolean  -- true = já passou pelo job de re-hospedagem
)
language sql
stable
as $$
  select
    t.ad_id::text,
    t.ad_name::text,
    coalesce(t.storage_url, t.image_url, t.thumbnail_url)::text as url,
    t.storage_video_url::text as video_url,
    (t.synced_at is not null) as sincronizado
  from core.ads_thumbnails t
  where t.ad_id::text = p_ad_id
  limit 1;
$$;

-- Teste: deve devolver 1 linha, com url e video_url preenchidos.
select * from mkt_wep.fn_ad_thumbnail('120239811109450777');
