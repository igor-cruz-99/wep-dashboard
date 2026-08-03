# WEP — Dashboard de marketing (Workshop Estrategista Patrimonial)

React + Vite + TS + Tailwind v4. Backend Supabase (2 projetos). Deploy Vercel via git push.
Repo: `igor-cruz-99/wep-dashboard`. **A raiz do projeto é a subpasta `WEP - DASHBOARD/`** (o cwd é `Desktop/Claude`, um nível acima) — sempre referencie arquivos como `WEP - DASHBOARD/...`, senão o link não abre.

## Arquitetura (porteiro + 2 Supabase)
- **AUTH** (funcionários): só login. O navegador só fala com esse.
- **DADOS** (Quartavia, schema `mkt_wep`): passa por `/api/dashboard` (serverless; local = plugin vite `localApi`). O porteiro valida o token e só então consulta com `service_role`. Allowlist por domínio (`quartavia.com.br`).
- Cálculo pesado mora em **RPCs no Postgres** (`fn_kpis`, `fn_funil`, `fn_serie_diaria`, `fn_trafego`, …). Cards/funil/investimento vêm daí, NÃO da tabela — filtrar só no front não muda os agregados.

## Segurança (não quebrar)
- `service_role` **nunca** com prefixo `VITE_`; só em `.env.local` (gitignored) e nas env vars da Vercel. Nada de segredo hardcoded — tudo por `process.env`/`import.meta.env`.
- Repo é público de propósito (ver `sql/`? não — ver memória `wep-deploy-vercel`). Segurança não depende de sigilo do código.

## Workflow (economia de tokens + clareza)
- **SQL via arquivo, não pelo chat.** Escrevo `WEP - DASHBOARD/sql/NN_*.sql`; o Igor abre o arquivo e cola no SQL Editor do Supabase. Rodar migração de RPC **antes** de subir o front que a usa (senão a página quebra — RPCs de KPI/funil/série não têm try/catch).
- **Adicionar param a uma RPC cria sobrecarga** → `drop function` das assinaturas antigas antes de recriar. Params novos com `default null` pra não quebrar chamadas existentes.
- **`npm run build` local antes de todo push.** `vite dev` NÃO roda type-check; `tsc -b` (no build) sim — já quebrou deploy por `string|null` num `.includes()`.
- **Deploy:** commit + push na `main` → Vercel builda. Conferir: `gh api repos/igor-cruz-99/wep-dashboard/deployments` (status `success`).
- **Dev sem login:** `VITE_DEV_SKIP_AUTH=1` + `DEV_SKIP_AUTH=1` no `.env.local` (as duas). Sempre voltar pra `0` antes de subir.
- **Sondar o banco:** script `.mjs` importando supabase-js de `node_modules`, lendo `.env.local`, service_role, schema `mkt_wep` (`.schema('core')` p/ core.vendas_pagarme).

## Etapas (sidebar)
`view`: `meteorico` | `padrao` | `seal`. O que separa Meteórico de Padrão é a **data** (não a tag). `filters.grupo === 'padrao'` identifica exatamente a etapa Padrão (Meteórico/SEAL usam `pre_venda`).

## Convenções
pt-BR. Explicações curtas por padrão (detalhar só se o Igor pedir). Verificar antes de afirmar; sinalizar risco sem decidir por ele.
