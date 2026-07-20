/** Formatações no padrão brasileiro (R$, milhares, %). */

const brl = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
})

const int = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 })

export const formatBRL = (v: number) => brl.format(v)
export const formatInt = (v: number) => int.format(v)
export const formatPct = (v: number) => `${Math.round(v)}%`
