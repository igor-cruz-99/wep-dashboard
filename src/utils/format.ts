/** Formatações no padrão brasileiro (R$, milhares, %). */

const brl = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
})

const int = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 })

const dec1 = new Intl.NumberFormat('pt-BR', {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
})

const pct2 = new Intl.NumberFormat('pt-BR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
})

export const formatBRL = (v: number) => brl.format(v)
export const formatInt = (v: number) => int.format(v)
export const formatPct = (v: number) => `${Math.round(v)}%`

/** Número com 1 casa (ex.: frequência "1,9"). */
export const formatDec1 = (v: number) => dec1.format(v)
/** % com 2 casas — taxas pequenas (CTR) somem se arredondadas para inteiro. */
export const formatPct2 = (v: number) => `${pct2.format(v)}%`
