# Roadmap — o que falta (~20% do projeto)

> Estado atual: painel no ar em https://wep-dashboard-xi.vercel.app
> Ver `README.md` para a arquitetura e `sql/` para os scripts (numerados na ordem de execução).

---

## 1. Métricas sobrepostas no funil de conversão

Caixas brancas **sobrepostas nas bordas entre as etapas** do funil, alternando
esquerda/direita (referência visual: quadrados brancos "flutuando" sobre o funil).

### Fórmulas

| Métrica | Fórmula | Lado | Entre as etapas |
|---|---|---|---|
| **Frequência** | Impressões ÷ Alcance | direita | Alcance → Impressões |
| **CPM** | (Investimento ÷ Impressões) × 1000 | esquerda | Impressões → Cliques |
| **CTR** | Cliques ÷ Impressões | direita | Impressões → Cliques |
| **CPC** | Investimento ÷ Cliques | esquerda | Cliques → Page Views |
| **Connect Rate** | Page Views ÷ Cliques | direita | Cliques → Page Views |
| **CPLV** | Investimento ÷ Page Views | esquerda | Page Views → Checkouts |
| **Conversão Página** | Vendas ÷ Page Views | direita | Page Views → Checkouts |
| **CAC** | (substitui o antigo "CPL" — usar o CAC já calculado) | esquerda | Checkouts → Vendas |

### Notas de implementação
- Todos os insumos **já vêm** da RPC `fn_funil` (investimento, alcance, impressões,
  cliques, page views, checkouts, vendas) — dá para calcular no front, sem SQL novo.
- O **CAC** já existe em `fn_kpis` (investimento ÷ vendas). Reaproveitar, não recalcular.
- Formatação: `CPM/CPC/CPLV/CAC` em R$; `Frequência` em número (1,9);
  `CTR/Connect Rate/Conversão Página` em %.
- Cuidado com divisão por zero (o painel já tem esse padrão nas tabelas).

---

## 2. View do produto principal (SEAL) — `core.vendas_pagarme`

### Origem
Tabela `core.vendas_pagarme`. Colunas relevantes:

```
order_id, status, data, hora, nome_completo, email, telefone,
valor_produto, valor_cobrado, metodo_pagamento, produto, codigo_produto,
parcelas, cidade, estado, customer_id, transaction_id,
last_utm_source, last_utm_campaign, last_utm_medium, last_utm_content,
last_utm_term, last_utm_pagina, last_funil, last_origem, vendido_por
```

Exemplo de linha: `status='paid'`, `produto='SEAL - Complemento'`,
`last_utm_campaign='ra-WEP-WEPMAR26-...'`, `last_origem='WEPMAR26'`.

### Regra de negócio (o ponto central)
Existem **três nomes de produto**:
- `Seal® - Taxa de Reserva` → pagou **só a reserva**
- `SEAL - Complemento` → pagou o **restante**
- `Seal®` → pagou **tudo de uma vez**

A view precisa dizer, **por aluno**, se ele:
- pagou **somente a taxa de reserva**, ou
- **quitou** (Taxa de Reserva + Complemento, **ou** `Seal®` numa tacada só)

**O agrupamento é pelo campo `email`** (é a chave que identifica o aluno).

### Pontos a definir antes de implementar
- Filtrar por `status`? (no exemplo vem `paid` — confirmar quais contam)
- O valor total do aluno é a soma de `valor_cobrado` das linhas dele?
- Ligar com as tags do WEP via `last_origem` / `last_utm_campaign` (`ILIKE '%wep%'`)?
- Onde isso aparece no painel: tabela nova? KPI? bloco próprio?

---

## 3. Gráficos das respostas das pesquisas

Fonte: `mkt_wep.wep_pesquisa` (tem a coluna `renda`, a coluna `qualificacao`
e o campo `respostas` em JSON).

| Gráfico | Dado |
|---|---|
| **Barras** | Renda |
| **Rosca (donut)** | Idade |
| **Barras** | Profissão |
| **Pizza** | Gênero |

### Pontos a definir
- `idade`, `genero` e `profissao` estão dentro do JSON `respostas`
  (o exemplo mostrava `{"idade":"35 a 44 anos","genero":"Masculino"}`) — confirmar
  as chaves exatas e se `profissao` existe.
- Provável necessidade de uma RPC nova que agrupe e conte por categoria
  (não trazer linha a linha para o front).
- Recharts já está no projeto (tem `PieChart`, e rosca = Pie com `innerRadius`).

---

## Pendências técnicas herdadas

- 🔴 **Rotacionar a `service_role`** do projeto de dados (exposta em conversa).
  Formato JWT antigo derruba anon + service_role juntas → quebraria o Quartavia
  e as automações. Ideal: criar uma **secret key dedicada** (`sb_secret_*`).
  Ao trocar, atualizar em **dois lugares**: `.env.local` e as Environment
  Variables do Vercel.
- 🟢 Colunas sempre zeradas: "Qualificação" (tabela de tráfego) e "Pesquisa"
  (tabela de páginas) — não há como preencher no modelo atual. Remover ou documentar.
- 🟢 Polimento: skeletons de loading, favicon + título da aba.
