-- ============================================================================
-- Seção Páginas: print da hero no CELULAR, além do desktop.
--
-- Por que o celular vira o print principal (é o que aparece no card): o tráfego
-- das LPs vem da Meta, e todas as vendas de ago/26 com posicionamento
-- identificado vieram de Instagram Feed, Reels e Stories ou do feed e stories
-- do Facebook no celular. A hero de desktop é a que quase ninguém vê — mostrar
-- só ela seria avaliar a headline numa tela diferente da do lead.
--
-- O desktop continua em `hero_url` e aparece ao lado, no popup.
--
-- A coluna é preenchida pelo scripts/capturar-hero-paginas.mjs. O INSERT do
-- sql/81 não a menciona, então re-rodar o catálogo não apaga os prints.
-- ============================================================================
alter table mkt_wep.paginas_catalogo add column if not exists hero_mobile_url text;

-- A função ganha a coluna no retorno. Mudar o formato do retorno exige drop.
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
  hero_mobile_url text,
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
  select c.pagina, c.tag, c.lp, c.variante, c.single_shot, c.head, c.link,
         c.hero_url, c.hero_mobile_url,
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

-- ── Conferência ─────────────────────────────────────────────────────────────
-- As 8 páginas, agora com as duas colunas de print (nulas até rodar o script):
select lp, variante, single_shot,
       hero_mobile_url is not null as tem_print_celular,
       hero_url        is not null as tem_print_desktop,
       page_views
  from mkt_wep.fn_paginas_galeria('WEPSET26', '2026-09-10', '2026-09-20');
