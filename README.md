# WEP — Dashboard Workshop Estrategista Patrimonial

Painel de tráfego e vendas em **React + Vite + TypeScript + Tailwind v4**,
com dados no **Supabase**.

## Arquitetura (dois projetos Supabase + porteiro)

```
Login    ──► Supabase AUTH (funcionários)         ← sessão do usuário
Dados    ──► /api/dashboard (servidor) ──► Supabase DADOS (mkt_wep)
             valida o token          usa service_role
```

O navegador **nunca** fala direto com o banco de dados: ele chama a API
`/api/dashboard`, que valida a sessão e só então consulta o Supabase com a
`service_role` (que fica só no servidor). O schema `mkt_wep` está **fechado**
para `anon` — sem passar pela API, ninguém lê nada.

## Rodar

```bash
npm install
npm run dev       # http://localhost:5184 — sobe o site E a API /api/dashboard
```

> O `vite.config.ts` tem um plugin (`localApi`) que serve a mesma função da
> `api/dashboard.ts` durante o desenvolvimento. Em produção, quem serve é a
> Vercel. Ou seja: **não precisa do Vercel CLI para rodar local.**

## Variáveis de ambiente

Em `.env.local` (local) e nas *Environment Variables* do Vercel (produção):

```
# CLIENTE (vai pro navegador) — só login
VITE_SUPABASE_AUTH_URL=...
VITE_SUPABASE_AUTH_ANON_KEY=...

# SERVIDOR (nunca vai pro navegador)
SUPABASE_URL=...              # projeto de dados
SUPABASE_SERVICE_ROLE=...     # ⚠️ segredo — sem prefixo VITE_
SUPABASE_AUTH_URL=...
SUPABASE_AUTH_ANON_KEY=...
```

> 🔑 **Regra de ouro:** o prefixo `VITE_` publica a variável no bundle do
> navegador. A `service_role` **jamais** pode ter esse prefixo.

## Estrutura

```
src/
├── components/
│   ├── ui/        Panel (cartão base)
│   ├── layout/    Header (título + filtros de tag/período)
│   ├── kpi/       KpiCard (com cor de %meta)
│   ├── charts/    LineChartCard (Recharts)
│   ├── funnel/    Funnel
│   └── tables/    TrafficTable, PagesTable
├── pages/         Dashboard (monta o painel)
├── lib/           supabase.ts (cliente)
├── utils/         metaColor.ts (degradê vermelho→verde), format.ts (R$, %)
├── data/          mock.ts (dados fictícios — substituir por queries reais)
└── types/         contratos de dados (Kpi, FunnelStage, TrafficRow, ...)
```

## Cores de %meta

- **Normal** (Vendas, Faturamento, Grupo, Qualificação): 0% vermelho → 50% amarelo → 100% verde
- **CAC (invertido)**: <=100% verde → amarelo → >100% vermelho

Lógica em `src/utils/metaColor.ts`.

## Próximo passo

Trocar `src/data/mock.ts` por queries reais do Supabase (`src/lib/supabase.ts`)
quando os schemas/tabelas forem definidos. Cálculos pesados (CAC, funil, taxas)
devem virar **VIEWS** no Postgres.
