import { useMemo, useState } from 'react'
import type { PageRow } from '../../types'
import { formatInt, formatPct } from '../../utils/format'
import { heatBg, norm, type HeatMode } from '../../utils/heat'
import { Panel, SectionTitle } from '../ui/Panel'

/** Taxa segura (evita divisão por zero). */
const ratio = (a: number, b: number) => (b === 0 ? 0 : (a / b) * 100)

interface Column {
  label: string
  get: (r: PageRow) => number | string
  fmt: (r: PageRow) => string
  num: boolean
  agg: 'sum' | 'avg' | 'none'
  fmtAgg: (n: number) => string
  heat: HeatMode
}

const columns: Column[] = [
  { label: 'Página', get: (r) => r.pagina, fmt: (r) => r.pagina, num: false, agg: 'none', fmtAgg: () => '', heat: 'none' },
  { label: 'Page View', get: (r) => r.pageView, fmt: (r) => formatInt(r.pageView), num: true, agg: 'sum', fmtAgg: formatInt, heat: 'heat' },
  { label: 'Checkout', get: (r) => r.checkout, fmt: (r) => formatInt(r.checkout), num: true, agg: 'sum', fmtAgg: formatInt, heat: 'heat' },
  { label: 'Vendas', get: (r) => r.vendas, fmt: (r) => formatInt(r.vendas), num: true, agg: 'sum', fmtAgg: formatInt, heat: 'heat' },
  { label: 'Leads', get: (r) => r.leads, fmt: (r) => formatInt(r.leads), num: true, agg: 'sum', fmtAgg: formatInt, heat: 'heat' },
  { label: 'Pesquisa', get: (r) => r.pesquisa, fmt: (r) => formatInt(r.pesquisa), num: true, agg: 'sum', fmtAgg: formatInt, heat: 'heat' },
  { label: 'Checkout x Venda', get: (r) => ratio(r.vendas, r.checkout), fmt: (r) => formatPct(ratio(r.vendas, r.checkout)), num: true, agg: 'avg', fmtAgg: formatPct, heat: 'heat' },
  { label: 'Visita x Checkout', get: (r) => ratio(r.checkout, r.pageView), fmt: (r) => formatPct(ratio(r.checkout, r.pageView)), num: true, agg: 'avg', fmtAgg: formatPct, heat: 'heat' },
  { label: 'Visita x Venda', get: (r) => ratio(r.vendas, r.pageView), fmt: (r) => formatPct(ratio(r.vendas, r.pageView)), num: true, agg: 'avg', fmtAgg: formatPct, heat: 'heat' },
]

/** Soma ou média de uma coluna sobre as linhas visíveis. */
function aggregate(rows: PageRow[], get: (r: PageRow) => number, mode: 'sum' | 'avg') {
  if (rows.length === 0) return 0
  const sum = rows.reduce((acc, r) => acc + Number(get(r)), 0)
  return mode === 'avg' ? sum / rows.length : sum
}

export function PagesTable({ rows }: { rows: PageRow[] }) {
  const [q, setQ] = useState('')
  const [sort, setSort] = useState<{ idx: number; dir: 'asc' | 'desc' } | null>(null)

  const view = useMemo(() => {
    const filtered = rows.filter((r) => r.pagina.toLowerCase().includes(q.trim().toLowerCase()))
    if (!sort) return filtered
    const col = columns[sort.idx]
    return [...filtered].sort((a, b) => {
      const av = col.get(a)
      const bv = col.get(b)
      const cmp = col.num
        ? (av as number) - (bv as number)
        : String(av).localeCompare(String(bv), 'pt-BR')
      return sort.dir === 'desc' ? -cmp : cmp
    })
  }, [rows, q, sort])

  // Faixa (min/max) por coluna para o mapa de calor.
  const bounds = useMemo(
    () =>
      columns.map((c) => {
        if (c.heat === 'none' || view.length === 0) return null
        const vals = view.map((r) => Number(c.get(r)))
        return { min: Math.min(...vals), max: Math.max(...vals) }
      }),
    [view]
  )

  const onSort = (idx: number) =>
    setSort((s) => (s?.idx === idx ? { idx, dir: s.dir === 'desc' ? 'asc' : 'desc' } : { idx, dir: 'desc' }))

  return (
    <Panel className="p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <SectionTitle overline="Análise" title="Desempenho por página" />
        <div className="flex w-full max-w-xs items-center gap-2 rounded-full border border-line bg-card-2 px-4 py-2">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" aria-hidden>
            <circle cx="11" cy="11" r="7" stroke="#a3907a" strokeWidth="2" />
            <path d="m20 20-3.5-3.5" stroke="#a3907a" strokeWidth="2" strokeLinecap="round" />
          </svg>
          <input
            placeholder="Buscar página"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="w-full bg-transparent text-sm text-cream outline-none placeholder:text-muted"
          />
        </div>
      </div>

      {/* ~7 linhas visíveis; o resto rola. Cabeçalho fixo e clicável (ordena). */}
      <div className="max-h-[352px] overflow-auto rounded-xl border border-line">
        <table className="w-full border-collapse text-sm">
          <thead className="sticky top-0 z-10">
            <tr className="bg-card-2 text-left text-muted">
              {columns.map((c, i) => {
                const active = sort?.idx === i
                return (
                  <th
                    key={c.label}
                    onClick={() => onSort(i)}
                    className="cursor-pointer select-none bg-card-2 px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.12em] whitespace-nowrap hover:text-cream"
                  >
                    <span className="inline-flex items-center gap-1">
                      {c.label}
                      <span className={active ? 'text-gold' : 'text-transparent'}>
                        {active && sort?.dir === 'asc' ? '▲' : '▼'}
                      </span>
                    </span>
                  </th>
                )
              })}
            </tr>
          </thead>
          <tbody>
            {view.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-6 text-center text-xs text-muted">
                  Nenhuma página encontrada.
                </td>
              </tr>
            ) : (
              view.map((r) => (
                <tr key={r.id} className="border-t border-line">
                  {columns.map((c, i) => {
                    if (i === 0) {
                      return (
                        <td key={c.label} className="px-4 py-3 font-medium whitespace-nowrap text-cream">
                          {c.fmt(r)}
                        </td>
                      )
                    }
                    const b = bounds[i]
                    const bg = b ? heatBg(norm(Number(c.get(r)), b.min, b.max), c.heat) : undefined
                    return (
                      <td key={c.label} className="px-4 py-3 text-cream" style={{ background: bg }}>
                        {c.fmt(r)}
                      </td>
                    )
                  })}
                </tr>
              ))
            )}
          </tbody>
          {view.length > 0 && (
            <tfoot className="sticky bottom-0 z-10">
              <tr className="border-t-2 border-line bg-card-2">
                {columns.map((c, i) => (
                  <td
                    key={c.label}
                    className="bg-card-2 px-4 py-3 text-[13px] font-bold whitespace-nowrap text-cream"
                  >
                    {i === 0
                      ? 'Total / Média'
                      : c.fmtAgg(aggregate(view, (r) => c.get(r) as number, c.agg === 'avg' ? 'avg' : 'sum'))}
                  </td>
                ))}
              </tr>
            </tfoot>
          )}
        </table>
      </div>
    </Panel>
  )
}
