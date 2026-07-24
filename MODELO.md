# Dashboard WEB Pro — Guia do Modelo

Base reutilizável para painéis de tráfego/vendas com **React + Vite + TypeScript
+ Tailwind v4** e dados no **Supabase**, protegidos por um servidor "porteiro".

Este arquivo é o mapa do projeto: a arquitetura, o que cada arquivo faz, e como
adaptar tudo para um novo cliente/lançamento.

---

## 1. O que este modelo entrega

- Painel com **KPIs** (com meta, cor e barra de progresso), **funil de conversão**
  com métricas sobrepostas, **gráficos diários** (barra + linha combo), **tabelas**
  com mapa de calor, e blocos de **pesquisa** e **produto (SEAL)**.
- **Filtro global** por período (e por "tag"/lançamento).
- **Segurança de verdade**: o navegador nunca toca o banco de dados.
- **Deploy** contínuo na Vercel (push → build automático).
- Padrões que evitam retrabalho: fetch tolerante a falha, cálculo pesado no
  Postgres, tema centralizado, formatação BR.

---

## 2. Stack

| Camada | Tecnologia |
|---|---|
| Front | React 19 · Vite · TypeScript · Tailwind v4 |
| Gráficos | Recharts |
| Backend | Função serverless (Vercel) — `api/dashboard.ts` |
| Dados | Supabase (Postgres) — dois projetos: **auth** e **dados** |
| Deploy | Vercel (conectado ao GitHub) |
| Lint | oxlint |

---

## 3. Arquitetura — o padrão "dois projetos + porteiro"

```
                    LOGIN
Navegador ──────────────────────────► Supabase AUTH (só funcionários)
    │                                   devolve a sessão (JWT)
    │
    │        DADOS (com o token da sessão)
    └──► /api/dashboard  ──valida o token──►  Supabase DADOS
         (servidor Vercel)                    consulta com service_role
```

**Regras que sustentam a segurança:**

1. O front só conversa com o Supabase para **login** (projeto de auth).
2. Todo dado passa pela API `/api/dashboard`, que **valida a sessão** e só então
   consulta o banco com a `service_role` — que fica **só no servidor**.
3. O schema de dados é **trancado** para `anon` (`07_lock_anon.sql`): sem passar
   pela API, ninguém lê nada.
4. A `service_role` **nunca** tem prefixo `VITE_` (senão vaza no bundle).
5. Há uma **allowlist** de emails/domínios na API — "estar logado" não basta.

> Por que dois projetos Supabase: o login usa um projeto só de funcionários
> (barato de isolar); os dados ficam em outro projeto (do cliente), acessado
> apenas server-side. Um não derruba o outro.

---

## 4. Documentação arquivo por arquivo

### Raiz / configuração

| Arquivo | O que é |
|---|---|
| `package.json` | Deps e scripts (`dev`, `build`, `lint`). |
| `vite.config.ts` | Config do Vite + **plugin `localApi`**: serve a `api/dashboard.ts` no `npm run dev` (não precisa do Vercel CLI). Também define `manualChunks` (recharts/supabase/react em chunks próprios). |
| `index.html` | HTML base: favicon (`/favicon-64.png`) e `<title>`. |
| `tsconfig*.json` | TypeScript (app/node/base). |
| `.oxlintrc.json` | Regras do linter. |
| `.env.example` | **Modelo** das variáveis (vai pro Git, sem segredos). |
| `.env.local` | Variáveis reais — **no `.gitignore`**, nunca versionado. |
| `.gitignore` | Ignora `node_modules`, `dist`, `.env*`. |
| `.claude/launch.json` | Config do dev server para a ferramenta de preview. |

### `api/` — o porteiro (servidor)

| Arquivo | O que é |
|---|---|
| `api/dashboard.ts` | **Coração da segurança.** Recebe `{ fn, params }`, valida o token no projeto de auth, checa a **allowlist**, e só então chama a RPC no projeto de dados com a `service_role`. Tem uma **allowlist de RPCs** (`ALLOWED_RPC`) — só funções conhecidas rodam. Tem o interruptor `DEV_SKIP_AUTH` (só fora de produção). |

### `src/` — aplicação

| Arquivo | O que é |
|---|---|
| `main.tsx` | Ponto de entrada React. |
| `App.tsx` | Decide **Login × Dashboard** pela sessão. Respeita o bypass de dev. |
| `index.css` | **Tema** (Tailwind v4 `@theme`): cores (`bg`, `card`, `cream`, `gold`…), fontes. Mexa aqui para reskin. |
| `App.css` | Estilos pontuais. |

**`src/pages/`**

| Arquivo | O que é |
|---|---|
| `Dashboard.tsx` | Monta o painel: estado dos filtros, `PERIODO_PADRAO`, e a ordem dos blocos. É onde se decide **o que aparece e em que ordem**. |
| `Login.tsx` | Tela de login (email/senha + Google), com a logo. |

**`src/components/`**

| Arquivo | O que é |
|---|---|
| `ui/Panel.tsx` | Cartão base (`Panel`) + `SectionTitle`. Todo bloco usa. |
| `layout/Header.tsx` | Cabeçalho: logo, filtro de tag, atalhos 30D/7D/1D, período, logout. |
| `kpi/KpiCard.tsx` | Cartão de KPI: valor, meta, %atingimento colorido, barra. Suporta card **sem meta** (só o valor). Exporta `TrendArrow`. |
| `charts/ChartCard.tsx` | Gráfico diário. Barra, área, ou **combo** (barra + linha com eixo duplo). Bolinha colorida por série no título. |
| `funnel/Funnel.tsx` | Funil de conversão: trapézios em degradê + **métricas sobrepostas** nas bordas (CPM, CTR, CPL, Conversão…). |
| `tables/TrafficTable.tsx` | Tabela de tráfego (campanha→conjunto→anúncio), com busca, ordenação e mapa de calor. |
| `tables/PagesTable.tsx` | Tabela de desempenho por página. |
| `pesquisa/PesquisaCharts.tsx` | Grid 2×2 dos gráficos de pesquisa (barras/rosca/pizza) + resumo no título. |
| `seal/SealCards.tsx` | Cartões do produto SEAL (quitou / só reserva / CAC). |
| `seal/SealBuyersTable.tsx` | Tabela de compradores do produto, com UTMs. |

**`src/hooks/`**

| Arquivo | O que é |
|---|---|
| `useAuth.ts` | Estado da sessão (Supabase Auth). |
| `useDashboardData.ts` | **Orquestra os fetches**: dispara todas as queries em paralelo a cada mudança de filtro e junta num objeto. |

**`src/lib/`**

| Arquivo | O que é |
|---|---|
| `supabase.ts` | Cliente Supabase **só de auth** (login). Não há cliente de dados no front. |
| `queries.ts` | **Todas as chamadas de dados.** Cada `fetchX` chama uma RPC via `/api/dashboard` e mapeia o retorno para os tipos do front. Blocos opcionais são **tolerantes** (RPC ausente → vazio, não quebra). |
| `devAuth.ts` | Flag `DEV_SKIP_AUTH` (pula login em dev). Dupla trava: `import.meta.env.DEV` + a env sem `VITE_`. |

**`src/utils/`**

| Arquivo | O que é |
|---|---|
| `format.ts` | Formatação BR: `formatBRL`, `formatInt`, `formatPct`, `formatDec1`, `formatPct2`. |
| `metaColor.ts` | Cor da %meta: degradê vermelho→amarelo→verde. Direção `normal` (maior=melhor) ou `inverse` (CAC/CPL: menor=melhor). |
| `heat.ts` | Mapa de calor das células das tabelas. |

**`src/types/index.ts`** — Contratos de dados (`Kpi`, `FunnelStage`, `TrafficRow`,
`PageRow`, `PesquisaPerfil`, `SealResumo`, `Filters`…). Fonte da verdade dos tipos.

### `sql/` — banco (rodar no SQL Editor do Supabase, na ordem)

Cálculo pesado mora aqui, não no front. Numerados na ordem de execução.

| # | Arquivo | O que faz |
|---|---|---|
| 01 | `01_views_mkt_wep.sql` | Views base (ads, vendas, checkouts, páginas, grupos, pesquisa) + `norm_pagina`. |
| 02 | `02_rpc_mkt_wep.sql` | RPCs de agregação: `fn_kpis`, `fn_funil`, `fn_serie_diaria`, `fn_trafego`, `fn_paginas`. |
| 03 | `03_seed_wep_tags.sql` | Tags/lançamentos + metas. |
| 04 | `04_fix_tags_rls.sql` | RLS da tabela de tags. |
| 05 | `05_dashboard_auth.sql` | Apoio à autenticação. |
| 06 | `06_index_ads_trgm.sql` | Índice trigram (performance das buscas em ads). |
| 07 | `07_lock_anon.sql` | **Tranca o schema** para anon/authenticated (só service_role lê). |
| 08 | `08_rpc_pesquisa.sql` | RPC dos gráficos de pesquisa. |
| 09 | `09_view_seal.sql` | Produto SEAL (situação por email). |
| 10 | `10_table_wep_cadastro.sql` | Tabela de cadastros da captação (leads). |
| 11 | `11_leads.sql` | Leads nos KPIs, tráfego e páginas. |
| 12 | `12_meta_investimento.sql` | Meta de investimento. |
| 13 | `13_serie_leads.sql` | Leads na série diária. |
| 14 | `14_seal_periodo.sql` | SEAL filtrado por período. |
| 15 | `15_fix_trafego_utm.sql` | Correção de nome de coluna UTM. |
| 16–17 | `16..17_*tkp*.sql` | Exclui páginas de "obrigado" (%tkp%). |
| 18 | `18_funil_leads.sql` | Etapa Leads no funil. |
| 19 | `19_meta_cpl.sql` | Meta de CPL. |
| 20 | `20_serie_pageviews.sql` | Page views na série diária (conversão da captação). |

> Os arquivos numerados são o **histórico** da modelagem. Num banco novo, rode
> em ordem — os posteriores sobrescrevem os anteriores quando preciso.

### Outros

| Pasta/arquivo | O que é |
|---|---|
| `public/` | Assets estáticos: `logo.png`, `favicon-64.png`. Trocar por projeto. |
| `scripts/` | Scripts `.mjs` de **debug/verificação** usados durante o desenvolvimento (não vão para produção). Referência, podem ser removidos. |
| `src/assets/` | Assets do Vite (podem ser removidos). |
| `README.md` | Visão rápida (pode estar desatualizado — este `MODELO.md` é o guia oficial). |
| `ROADMAP.md` | O que falta / decisões / pendências do projeto. |

---

## 5. Como reusar em um novo projeto — passo a passo

1. **Copiar o repositório** e renomear (novo repo no GitHub).
2. **Supabase:** reusar o projeto de auth (funcionários) e criar/usar um projeto
   de **dados** para o novo cliente. Ajustar o schema (as tabelas viram as suas).
3. **Env:** preencher `.env.local` (local) e as *Environment Variables* na Vercel
   — as mesmas 4 do servidor + as 2 `VITE_` do cliente. Preencher a **allowlist**
   (`DASHBOARD_ALLOWED_DOMAINS` / `_EMAILS`).
4. **Banco:** usar os `sql/01..07` como base da segurança e adaptar as views/RPCs
   (`fn_kpis`, `fn_funil`…) para as **métricas do novo projeto**. Registrar cada
   RPC na `ALLOWED_RPC` de `api/dashboard.ts`.
5. **Front:**
   - `src/lib/queries.ts` — apontar os `fetchX` para as suas RPCs e mapear os tipos.
   - `src/types/index.ts` — ajustar os contratos.
   - `src/pages/Dashboard.tsx` — montar os blocos que fizerem sentido; ajustar `PERIODO_PADRAO`.
   - `src/index.css` — trocar as cores do tema.
   - `public/logo.png` + `index.html` `<title>` — a marca do cliente.
6. **Deploy:** conectar o repo na Vercel → push na `main` publica.

---

## 6. Convenções e armadilhas (aprendidas na prática)

- **`service_role` nunca com `VITE_`.** É a chave total do banco; com prefixo,
  vaza no bundle do navegador.
- **Cálculo pesado vira RPC/view no Postgres**, não soma no front (a API do
  Supabase corta em 1.000 linhas por request — somar no navegador dá total errado).
- **Fetch tolerante:** blocos opcionais (pesquisa, SEAL…) capturam erro e
  devolvem vazio. Assim uma RPC ainda não aplicada não derruba o painel inteiro.
- **`vw_tags` congela o `select *`:** ao adicionar coluna em `wep_tags`, **recrie
  a view** (`create or replace view vw_tags as select * ...`), senão as funções
  que leem metas falham com `column ... does not exist`.
- **Mudança no retorno de uma função** (colunas novas) exige `drop function`
  antes do `create` — o Postgres não deixa `create or replace` mudar o retorno.
- **Divisão por zero → mostra `—`**, nunca `R$ 0,00` (que pareceria dado real).
- **Bypass de login em dev:** `VITE_DEV_SKIP_AUTH=1` + `DEV_SKIP_AUTH=1` no
  `.env.local`. Dupla trava impede vazar para produção (`import.meta.env.DEV` +
  `NODE_ENV`). Voltar para `0` restaura o login.
- **Formatação sempre BR** (`pt-BR`): R$, milhares, %, vírgula decimal.
- **Verificar antes de publicar:** `npx tsc -b --noEmit` + `npx oxlint` +
  `npm run build`, e conferir no preview antes do `git push`.
