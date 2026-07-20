/** Heatmap monocromático: uma cor só, intensidade pelo valor da coluna. */

// 'none' = sem cor (coluna de texto). Qualquer outro valor = colore por magnitude.
export type HeatMode = 'heat' | 'none'

// Cor base do heatmap: âmbar da marca (#e8b05c).
const HEAT_RGB = '232, 176, 92'

/** Normaliza value em [min,max] → 0..1. 0.5 quando todos iguais (neutro). */
export function norm(value: number, min: number, max: number): number {
  if (max === min) return 0.5
  return (value - min) / (max - min)
}

/**
 * Fundo monocromático para t∈[0,1]: valor mais alto = mais forte, mais baixo =
 * mais fraco. Alpha vai de 0.06 (fraco) a 0.40 (forte).
 */
export function heatBg(t: number, mode: HeatMode): string | undefined {
  if (mode === 'none') return undefined
  const x = Math.min(1, Math.max(0, t))
  const alpha = 0.06 + x * 0.34
  return `rgba(${HEAT_RGB}, ${alpha.toFixed(3)})`
}
