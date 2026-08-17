-- ============================================================================
-- Os hyperlinks das colunas K e L (arquivo feed/story) se perderam quando a
-- planilha foi convertida de .xlsx para Google Sheets — diagnóstico via API
-- confirmou: 201 células com link, nenhuma em K/L. O que restou:
--   coluna B = nome do anúncio        (texto)
--   coluna K = nome do arquivo feed   (texto, era hyperlink)
--   coluna L = nome do arquivo story  (texto, era hyperlink)
--   coluna V = link da PASTA no Drive (link vivo, 111 células)
--
-- Ou seja: dá para achar cada arquivo pela pasta + nome. Este arquivo prepara
-- a tabela para isso, sem perder os 87 fileId já extraídos do .xlsx.
--
-- Fluxo depois desta migração:
--   Workflow A (planilha, 6h)  -> grava pasta + nome do arquivo e, para quem
--                                 ainda não tem fileId, busca na pasta e grava.
--   Workflow B (download, 20m) -> inalterado, continua consumindo só fileId.
-- ============================================================================

alter table mkt_wep.criativos_drive add column if not exists drive_folder_id text;
alter table mkt_wep.criativos_drive add column if not exists arquivo_feed    text;
alter table mkt_wep.criativos_drive add column if not exists arquivo_story   text;

comment on column mkt_wep.criativos_drive.drive_folder_id is
  'Pasta do Drive (coluna V da planilha) onde procurar o arquivo pelo nome.';
comment on column mkt_wep.criativos_drive.arquivo_feed is
  'Nome do arquivo no Drive (coluna K). Usado para achar o fileId dentro da pasta.';

-- ── Fila de resolução de fileId (Workflow A) ───────────────────────────────
-- Quem tem pasta + nome mas ainda não tem fileId, e está veiculado em WEP.
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
        where lower(d.anuncio) = lower(c.ad_name)
          and d.campanha ilike '%wep%'
     )
   order by c.ad_name
   limit p_limit;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Colunas criadas (esperado: 3 linhas):
select column_name, data_type
  from information_schema.columns
 where table_schema = 'mkt_wep' and table_name = 'criativos_drive'
   and column_name in ('drive_folder_id', 'arquivo_feed', 'arquivo_story')
 order by column_name;

-- (b) Estado atual da tabela (esperado: 102 linhas, 87 com fileId, 0 sincronizados):
select count(*) as total,
       count(*) filter (where drive_feed_id is not null or drive_story_id is not null) as com_fileid,
       count(*) filter (where drive_folder_id is not null) as com_pasta,
       count(*) filter (where synced_at is not null) as sincronizados
  from mkt_wep.criativos_drive;

-- (c) Fila do Workflow B, que não pode ter mudado (esperado: 62):
select count(*) as fila_download from mkt_wep.fn_criativos_drive_pendentes(500);

-- (d) Fila do Workflow A — vazia agora, enche quando a planilha for lida
--     (os 15 sem fileId ainda não têm pasta gravada):
select count(*) as fila_resolver_fileid from mkt_wep.fn_criativos_sem_fileid(500);
