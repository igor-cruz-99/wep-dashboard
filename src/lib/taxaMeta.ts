import type { DashboardData } from '../hooks/useDashboardData'
import type { CriativoGaleria } from '../types'

/**
 * Taxa cobrada sobre o investimento em mídia. O painel lê o gasto direto da
 * Meta, que é o valor ANTES da taxa — ligar o botão mostra o custo real da
 * operação.
 */
export const TAXA_META = 0.12

/** Multiplicador aplicado ao investimento quando o botão está ligado. */
const fator = (ligado: boolean) => (ligado ? 1 + TAXA_META : 1)

/**
 * POR QUE BASTA MULTIPLICAR:
 *
 * Toda métrica afetada é o investimento ou um quociente que o tem no
 * numerador — CAC = inv/vendas, CPL = inv/leads, CPM = inv/impressões×1000,
 * CPC = inv/cliques, CPLV = inv/page views. O denominador de todas elas é
 * volume (vendas, leads, impressões), que a taxa não muda. Então
 *
 *     (inv × 1,12) / volume  =  (inv / volume) × 1,12
 *
 * e multiplicar o resultado pronto dá exatamente o mesmo que recalcular com o
 * investimento acrescido. Isso importa porque várias dessas métricas já vêm
 * calculadas das RPCs: não dá para "recalcular" sem refazer as consultas.
 *
 * O QUE NÃO MUDA, e é tão importante quanto: contagens (vendas, leads,
 * checkouts, page views, alcance, impressões, cliques), taxas de conversão,
 * CTR, frequência, faturamento e as METAS. Meta é alvo definido pela operação,
 * não custo — mexer nela esconderia justamente o que o botão quer mostrar, que
 * é o alvo ficando mais difícil quando a taxa entra na conta.
 */
export function comTaxaMeta(data: DashboardData, ligado: boolean): DashboardData {
  if (!ligado) return data
  const f = fator(ligado)

  return {
    ...data,
    // Cards: só investimento e os custos por unidade. Vendas, leads e
    // qualificação seguem intactos, assim como toda `meta`.
    kpis: data.kpis.map((k) =>
      k.id === 'investimento' || k.id === 'cac' || k.id === 'cpl'
        ? { ...k, value: k.value * f }
        : k
    ),
    // Funil: só a etapa Investimento. As métricas laterais (CPM, CPC, CPLV,
    // CAC) são derivadas dela dentro do componente, então acompanham sozinhas.
    funnel: data.funnel.map((s) =>
      s.label === 'Investimento' ? { ...s, value: s.value * f } : s
    ),
    series: {
      ...data.series,
      investimentoPorDia: data.series.investimentoPorDia.map((p) => ({ ...p, value: p.value * f })),
      cacPorDia: data.series.cacPorDia.map((p) => ({ ...p, value: p.value * f })),
    },
    traffic: data.traffic.map((r) => ({ ...r, investimento: r.investimento * f, cac: r.cac * f })),
    cplOrigem: {
      pagina: {
        ...data.cplOrigem.pagina,
        investimento: data.cplOrigem.pagina.investimento * f,
        cpl: data.cplOrigem.pagina.cpl * f,
      },
      nativo: {
        ...data.cplOrigem.nativo,
        investimento: data.cplOrigem.nativo.investimento * f,
        cpl: data.cplOrigem.nativo.cpl * f,
      },
    },
  }
}

/**
 * Mesma regra para a galeria de criativos, que não passa pelo DashboardData.
 * CTR e frequência ficam de fora: não têm investimento na conta.
 */
export function criativosComTaxaMeta(
  criativos: CriativoGaleria[],
  ligado: boolean
): CriativoGaleria[] {
  if (!ligado) return criativos
  const f = fator(ligado)
  return criativos.map((c) => ({
    ...c,
    investimento: c.investimento * f,
    cac: c.cac * f,
    cpm: c.cpm * f,
    cpc: c.cpc * f,
  }))
}
