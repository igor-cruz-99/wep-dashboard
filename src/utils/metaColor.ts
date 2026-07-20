/**
 * Lógica de cor dos percentuais de meta.
 *
 * Regra do painel WEP:
 *  - Métrica NORMAL  (Vendas, Faturamento, Entrada Grupo, Qualificação):
 *      0% → vermelho, 50% → amarelo, 100%+ → verde.  "Quanto maior, melhor."
 *  - Métrica INVERTIDA (CAC):
 *      ≤100% → verde, sobe pra amarelo e >100% vira vermelho. "Quanto menor, melhor."
 */

export type MetaDirection = 'normal' | 'inverse'

// Tons calibrados pra legibilidade sobre o fundo escuro.
const RED = { h: 12, s: 78, l: 58 }
const YELLOW = { h: 43, s: 80, l: 55 }
const GREEN = { h: 96, s: 45, l: 52 }

function lerp(a: number, b: number, t: number) {
  return a + (b - a) * t
}

/** Interpola entre três paradas: 0 = vermelho, 0.5 = amarelo, 1 = verde. */
function gradient(t: number): string {
  const clamped = Math.min(1, Math.max(0, t))
  const [from, to, seg] =
    clamped < 0.5 ? [RED, YELLOW, clamped / 0.5] : [YELLOW, GREEN, (clamped - 0.5) / 0.5]
  const h = lerp(from.h, to.h, seg)
  const s = lerp(from.s, to.s, seg)
  const l = lerp(from.l, to.l, seg)
  return `hsl(${h.toFixed(0)} ${s.toFixed(0)}% ${l.toFixed(0)}%)`
}

/**
 * Nota de 0 (péssimo) a 1 (ótimo) da métrica em relação à meta,
 * já considerando a direção. Usada pra cor, seta e barra de progresso.
 */
export function metaScore(pct: number, direction: MetaDirection = 'normal'): number {
  if (direction === 'inverse') {
    // 100% do CAC = ok (t=1); 200%+ do CAC = ruim (t=0).
    return Math.min(1, Math.max(0, 1 - (pct - 100) / 100))
  }
  return Math.min(1, Math.max(0, pct / 100))
}

/**
 * @param pct         percentual da meta atingido (ex.: 32, 105)
 * @param direction   'normal' (maior é melhor) ou 'inverse' (CAC: menor é melhor)
 */
export function metaColor(pct: number, direction: MetaDirection = 'normal'): string {
  return gradient(metaScore(pct, direction))
}
