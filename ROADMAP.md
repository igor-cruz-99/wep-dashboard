# Roadmap

> Painel no ar em https://wep-dashboard-xi.vercel.app
> Ver `README.md` para a arquitetura e `sql/` para os scripts (numerados na ordem de execução).

---

## ✅ Concluído

### 1. Métricas sobrepostas no funil
Caixas creme flutuando nas bordas entre as etapas, alternando esquerda/direita:
**Frequência, CPM, CTR, CPC, Connect Rate, CPLV, Conversão Página** e **CAC**.
Tudo calculado no front a partir da `fn_funil` (sem SQL novo); o CAC é reaproveitado
da `fn_kpis`. Divisão por zero mostra `—` (não `R$ 0,00`, que pareceria dado real).

### 2. SEAL — situação de pagamento (`sql/09` + `sql/14`)
Agrupado por **email**, considerando `status = 'paid'`:
- pagou **Complemento** ou **Seal®** integral → **quitou**
- só a **Taxa de Reserva** → **só reserva**

Entrega: 2 cards (Quitaram / Só reserva) + **CAC SEAL** (investimento ÷ vendas
completas) + tabela de compradores com nome, email e UTMs. Os UTMs vêm da venda,
com fallback pelo email no pré-checkout (`wep_checkout`) quando vierem vazios.

**Filtra por período** pela data da compra (`sql/14`). A classificação considera só
as compras dentro do período — quem pagou reserva em março e complemento em maio
aparece como "só reserva" num filtro que pegue apenas março.

### 3. Gráficos das respostas das pesquisas (`sql/08`)
Grid 2×2: **Renda** e **Profissão** em barras horizontais (rótulo `valor (%)`),
**Idade** em rosca e **Gênero** em pizza, ambas com linha-guia. No título, o total
de respostas e o % sobre os leads: `8 (114% ↗)`.

### 4. Captação / Leads (`sql/10` a `sql/13`)
Tabela `mkt_wep.wep_cadastro` (nome, telefone, UTMs, tag, data) para a nova página
de captação. A partir dela:
- **KPI Leads** com meta vinda de `wep_tags.meta_leads`
- **Coluna Leads** em Tráfego (atribuída por UTM nos 3 níveis) e em Páginas (`utm_pagina`)
- Gráfico **Leads por dia | Conversão** (vendas ÷ leads)

### 5. Ajustes de layout e performance
- **6 KPIs** na ordem: Investimento → Leads → Vendas Ingressos → CAC → Entrada Grupo
  → Qualificação. Faturamento removido. Investimento com cor invertida
  (0–100% verde; acima de 100% vira laranja/vermelho).
- Gráficos **combo** barra+linha com bolinha colorida ao lado de cada série.
- **Conversão Checkout por dia** (nome corrigido — a métrica é Vendas ÷ Checkouts).
- **Logo, favicon e título da aba** — logo otimizada de 577 KB para 20 KB (−96%)
  e favicon dedicado de 3 KB.

---

## 🔴 Pendência de segurança

**Rotacionar a `service_role`** do projeto de dados (foi exposta em conversa).
O formato JWT antigo derruba anon + service_role juntas → quebraria o Quartavia
e as automações. Ideal: criar uma **secret key dedicada** (`sb_secret_*`).
Ao trocar, atualizar em **dois lugares**: `.env.local` e as Environment Variables
da Vercel.

---

## 🟡 Limitações conhecidas

- **Coluna "Qualificação"** (tabela de tráfego): sempre zero. A pesquisa não tem UTM,
  então não há como atribuir qualificação por campanha no modelo atual.
- **Coluna "Pesquisa"** (tabela de páginas): sempre zero, mesmo motivo — a pesquisa
  não é rastreada por página.
  → Ambas: remover as colunas ou preencher exige mudar a origem dos dados.
- **Leads no Tráfego** só aparecem quando `utm_campaing` + `utm_content` do cadastro
  batem com um anúncio real em `dim_anuncios` — mesmo critério já usado pelas vendas.
- **SEAL não filtra por tag**: `core.vendas_pagarme` não tem coluna `tag`; a origem
  fica em `last_origem`, que hoje não coincide com as tags cadastradas.

---

## 🟢 Polimento pendente

- Skeletons de loading (hoje é um spinner único).
- `public/favicon.svg` e `public/icons.svg` são órfãos — não referenciados em lugar
  nenhum desde que o favicon virou PNG. Podem ser removidos.

---

## Ordem dos scripts SQL

Todos já aplicados em produção. Rodar nesta ordem num banco novo:

| # | Arquivo | O que faz |
|---|---|---|
| 01 | `01_views_mkt_wep.sql` | Views base do schema |
| 02 | `02_rpc_mkt_wep.sql` | RPCs de agregação |
| 07 | `07_lock_anon.sql` | Tranca o schema (só service_role lê) |
| 08 | `08_rpc_pesquisa.sql` | Perfil das pesquisas |
| 09 | `09_view_seal.sql` | SEAL (substituído em parte pelo 14) |
| 10 | `10_table_wep_cadastro.sql` | Tabela de cadastros da captação |
| 11 | `11_leads.sql` | Leads nos KPIs, tráfego e páginas |
| 12 | `12_meta_investimento.sql` | Meta de investimento |
| 13 | `13_serie_leads.sql` | Leads na série diária |
| 14 | `14_seal_periodo.sql` | SEAL filtrado por período |

> ⚠️ Ao adicionar coluna em `wep_tags`, **recriar a `vw_tags`** — ela foi criada com
> `select *` e o Postgres congela as colunas de quando a view nasceu. Sem isso as
> funções que leem metas falham com `column ... does not exist`.

---

## Desenvolvimento

Para pular a tela de login ao ajustar o visual, em `.env.local`:

```
VITE_DEV_SKIP_AUTH=1
DEV_SKIP_AUTH=1
```

Só funciona em `npm run dev` — o cliente checa `import.meta.env.DEV` e a API checa
`NODE_ENV !== 'production'`, então na Vercel é sempre ignorado. Voltar para `0`
(e reiniciar o dev server) restaura o login normal.
