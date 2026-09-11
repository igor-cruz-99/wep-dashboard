-- ============================================================================
-- vw_paginas_diario: o critério passa a ser "wep OU estrategista".
--
-- O filtro era só '%wep%'. Ele vinha funcionando para o WEPSET26 por acidente:
-- o sufixo da edição é "-wepset26", que contém "wep". Se a próxima edição usar
-- "-out26" ou "-set26", as páginas somem do painel SEM ERRO NENHUM — só param
-- de aparecer. É o mesmo modo de falha silencioso que já nos custou dias com a
-- nomenclatura das LPs (sql/74) e com a planilha em .xlsx.
--
-- "estrategista" é o radical estável: está no caminho de toda página do
-- produto, independente de edição, de prefixo (workshop/imersao) e de sufixo.
--
-- POR QUE "OU" E NÃO TROCA. Medido em setembro/26:
--   só '%wep%'         : 282 views
--   só '%estrategista%': 266 views
--   perderíamos trocando: 37 views — /wep-lista-de-espera-h1v1/ (33),
--     /wep-replay-aula-1-bloco1/, /wep-lp01-h1
--   ganharíamos trocando: 21 views
-- Existem páginas do produto com "wep" e sem "estrategista", e vice-versa. Os
-- dois critérios juntos cobrem as duas famílias.
--
-- EFEITO COLATERAL DESEJADO: a lista de 13 páginas escritas à mão no sql/63
-- existia só para contornar a ausência do radical — todas contêm
-- "estrategista". Com o novo critério ela vira redundante e sai, junto das 4
-- exceções `ilike` do sql/52. Uma lista a menos para lembrar de atualizar
-- quando nascer página nova.
--
-- ⚠️ CUSTO NO ACUMULADO: entram 72 páginas e ~20.688 views de lançamentos
-- anteriores (dez/25 em diante) — a lp04-h1-v3 sozinha tem 8.784. Isso NÃO
-- atrapalha a leitura por edição, que é como o painel é usado: no recorte de
-- 10 a 20/09 essas páginas somam quase nada, porque quase todas pararam de
-- receber tráfego antes do dia 10. O lugar onde aparece é um período longo ou
-- o acumulado geral. Se um dia incomodar, dá para excluir nominalmente as
-- maiores (lp04-h1-v3, lp04-h1, lp04-singleshot, lp03-h1, lp06).
--
-- Usei "estrategista" inteiro em vez do radical "estrateg" de propósito: é
-- mais específico e não abre a porta para um produto futuro com "estratégia"
-- no nome entrar sozinho no painel do WEP.
--
-- As exclusões continuam todas: tkp (páginas de obrigado), as duas URLs com
-- utm colado, URL embutida e o tráfego de teste.
-- ============================================================================
create or replace view mkt_wep.vw_paginas_diario as
select
  data,
  mkt_wep.norm_pagina(caminho_da_pagina) as pagina,
  sum(visualizacoes)   as page_views,
  sum(usuarios_unicos) as usuarios_unicos
from core.paginas_ga4
where (
    caminho_da_pagina ilike '%wep%'
    or caminho_da_pagina ilike '%estrategista%'
  )
  and caminho_da_pagina not ilike '%tkp%'
  and caminho_da_pagina not ilike '%h2v4&utm_source=rec_email%'
  and caminho_da_pagina not ilike '%h2v40&utm_source=grupos_antigos%'
  and caminho_da_pagina !~* '.+https?:'
  and (source is null or lower(source) not in ('test', 'codex_browser_qa'))
group by data, mkt_wep.norm_pagina(caminho_da_pagina);

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) O QUE IMPORTA PARA A EDIÇÃO ATUAL: as páginas do WEPSET26 no período.
--     Elas JÁ apareciam antes (o "wep" de "wepset26"), então os números não
--     devem mudar — a migração é blindagem, não conserto. Se algum sumir, é
--     bug:
select pagina, sum(page_views) as views
  from mkt_wep.vw_paginas_diario
 where pagina ilike '%wepset26%'
   and data between '2026-09-10' and '2026-09-20'
 group by pagina
 order by views desc;

-- (b) As páginas que só têm "wep" continuam dentro — é o que se perderia numa
--     troca em vez de união (esperado: a lista de espera aparece):
select pagina, sum(page_views) as views
  from mkt_wep.vw_paginas_diario
 where pagina not ilike '%estrategista%'
 group by pagina
 order by views desc
 limit 10;

-- (c) As 13 páginas do sql/63 continuam aparecendo, agora pelo radical em vez
--     da lista à mão (esperado: 13 linhas, mesmos números de antes):
select pagina, sum(page_views) as views
  from mkt_wep.vw_paginas_diario
 where pagina = any (array[
   '/imersao-estrategista-patrimonial-lp01-h1',
   '/imersao-estrategista-patrimonial-ingresso-lp01-h1',
   '/imersao-estrategista-patrimonial-ingresso-lp01-h1-v2',
   '/imersao-estrategista-patrimonial-l-pv-l-h2',
   '/imersao-estrategista-patrimonial-l-pv-l-h2v5',
   '/imersao-estrategista-patrimonial-l-pv-l-h6-v1',
   '/imersao-estrategista-patrimonial-lp02-h1',
   '/imersao-estrategista-patrimonial-lp07-h1',
   '/imersao-estrategista-patrimonial-pl01-h1-v1',
   '/workshop-estrategista-patrimonial-lp01-h1',
   '/workshop-estrategista-patrimonial-lp02-h1',
   '/workshop-estrategista-patrimonial-lp04-h1-v3',
   '/workshop-estrategista-patrimonial-lp04-h1-v5-ht'
 ])
 group by pagina
 order by views desc;

-- (d) Nenhuma tkp entrou pela porta nova (esperado: 0 linhas):
select pagina from mkt_wep.vw_paginas_diario where pagina ilike '%tkp%';

-- (e) Nenhum produto ALHEIO entrou. Esta lista tem que conter só páginas do
--     WEP — se aparecer congresso-para-medicos, alavanca-patrimonial,
--     forum-patrimonial ou construtor-de-dolar, o critério pegou demais
--     (esperado: 0 linhas):
select pagina, sum(page_views) as views
  from mkt_wep.vw_paginas_diario
 where pagina !~* '(wep|estrategista)'
 group by pagina;

-- (f) Checkouts e vendas NÃO podem mudar — só page view foi mexido:
select sum(checkouts) as checkouts, sum(vendas) as vendas
  from mkt_wep.vw_pagina_resumo;

-- (g) O tamanho do acumulado antes/depois, para o número não surpreender:
--     esperado ~72 páginas e ~20.688 views a mais que antes.
select count(distinct pagina) as paginas, sum(page_views) as views
  from mkt_wep.vw_paginas_diario;
