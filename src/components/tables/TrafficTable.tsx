import { useMemo, useState } from 'react'
import type { TrafficRow } from '../../types'
import { formatBRL, formatInt, formatPct } from '../../utils/format'
import { heatBg, norm, type HeatMode } from '../../utils/heat'
import { Panel, SectionTitle } from '../ui/Panel'

/** Definição de coluna: valor pra ordenar/agregar + formatação de célula e rodapé. */
interface Column {
  label: string
  get: (r: TrafficRow) => number | string
  fmt: (r: TrafficRow) => string
  num: boolean
  /** Agregação no rodapé: soma, média ou nada (coluna de nome). */
  agg: 'sum' | 'avg' | 'none'
  fmtAgg: (n: number) => string
  /** Modo do mapa de calor. */
  heat: HeatMode
}

function buildColumns(firstCol: string): Column[] {
  return [
    { label: firstCol, get: (r) => r.nome, fmt: (r) => r.nome, num: false, agg: 'none', fmtAgg: () => '', heat: 'none' },
    { label: 'Investimento', get: (r) => r.investimento, fmt: (r) => formatBRL(r.investimento), num: true, agg: 'sum', fmtAgg: formatBRL, heat: 'heat' },
    { label: 'Vendas', get: (r) => r.vendas, fmt: (r) => formatInt(r.vendas), num: true, agg: 'sum', fmtAgg: formatInt, heat: 'heat' },
    { label: 'Leads', get: (r) => r.leads, fmt: (r) => formatInt(r.leads), num: true, agg: 'sum', fmtAgg: formatInt, heat: 'heat' },
    // CPL = Investimento ÷ Leads (custo por lead), por linha.
    { label: 'CPL', get: (r) => (r.leads > 0 ? r.investimento / r.leads : 0), fmt: (r) => formatBRL(r.leads > 0 ? r.investimento / r.leads : 0), num: true, agg: 'avg', fmtAgg: formatBRL, heat: 'heat' },
    { label: 'CAC', get: (r) => r.cac, fmt: (r) => formatBRL(r.cac), num: true, agg: 'avg', fmtAgg: formatBRL, heat: 'heat' },
    { label: 'Qualificação', get: (r) => r.qualificacao, fmt: (r) => formatPct(r.qualificacao), num: true, agg: 'avg', fmtAgg: formatPct, heat: 'heat' },
    { label: 'Hook', get: (r) => r.hook, fmt: (r) => formatPct(r.hook), num: true, agg: 'avg', fmtAgg: formatPct, heat: 'heat' },
    { label: 'Hold', get: (r) => r.hold, fmt: (r) => formatPct(r.hold), num: true, agg: 'avg', fmtAgg: formatPct, heat: 'heat' },
    { label: 'Body', get: (r) => r.body, fmt: (r) => formatPct(r.body), num: true, agg: 'avg', fmtAgg: formatPct, heat: 'heat' },
  ]
}

// Máximo de linhas renderizadas no DOM (o resto fica fora até refinar/ordenar).
const MAX_ROWS = 100

/** Soma ou média de uma coluna sobre as linhas visíveis. */
function aggregate<T>(rows: T[], get: (r: T) => number, mode: 'sum' | 'avg') {
  if (rows.length === 0) return 0
  const sum = rows.reduce((acc, r) => acc + Number(get(r)), 0)
  return mode === 'avg' ? sum / rows.length : sum
}

function SearchField({
  label,
  value,
  onChange,
}: {
  label: string
  value: string
  onChange: (v: string) => void
}) {
  return (
    <div className="flex items-center gap-2 rounded-full border border-line bg-card-2 px-4 py-2">
      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" aria-hidden>
        <circle cx="11" cy="11" r="7" stroke="#a3907a" strokeWidth="2" />
        <path d="m20 20-3.5-3.5" stroke="#a3907a" strokeWidth="2" strokeLinecap="round" />
      </svg>
      <input
        placeholder={label}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full bg-transparent text-sm text-cream outline-none placeholder:text-muted"
      />
    </div>
  )
}

interface MetricTableProps {
  title: string
  firstCol: string
  rows: TrafficRow[]
  selectedKey?: string | null
  onRowClick?: (row: TrafficRow) => void
  keyOf: (row: TrafficRow) => string | null
  emptyHint: string
}

function MetricTable({
  title,
  firstCol,
  rows,
  selectedKey,
  onRowClick,
  keyOf,
  emptyHint,
}: MetricTableProps) {
  const columns = useMemo(() => buildColumns(firstCol), [firstCol])
  const [sort, setSort] = useState<{ idx: number; dir: 'asc' | 'desc' } | null>(null)
  const clickable = Boolean(onRowClick)

  const sorted = useMemo(() => {
    if (!sort) return rows
    const col = columns[sort.idx]
    const arr = [...rows].sort((a, b) => {
      const av = col.get(a)
      const bv = col.get(b)
      const cmp = col.num
        ? (av as number) - (bv as number)
        : String(av).localeCompare(String(bv), 'pt-BR')
      return sort.dir === 'desc' ? -cmp : cmp
    })
    return arr
  }, [rows, sort, columns])

  // Faixa (min/max) por coluna para o mapa de calor.
  const bounds = useMemo(
    () =>
      columns.map((c) => {
        if (c.heat === 'none' || rows.length === 0) return null
        const vals = rows.map((r) => Number(c.get(r)))
        return { min: Math.min(...vals), max: Math.max(...vals) }
      }),
    [rows, columns]
  )

  // Só renderiza as primeiras MAX_ROWS (o cabeçalho/rodapé/heatmap usam o total).
  const capped = sorted.length > MAX_ROWS ? sorted.slice(0, MAX_ROWS) : sorted

  // 1º clique = decrescente; 2º no mesmo = crescente.
  const onSort = (idx: number) =>
    setSort((s) => (s?.idx === idx ? { idx, dir: s.dir === 'desc' ? 'asc' : 'desc' } : { idx, dir: 'desc' }))

  return (
    <div>
      <div className="mb-2 flex items-center gap-2">
        <h3 className="text-[11px] font-semibold uppercase tracking-[0.15em] text-muted">{title}</h3>
        <span className="rounded-full bg-card-2 px-2 py-0.5 text-[10px] text-muted">{rows.length}</span>
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
            {sorted.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-6 text-center text-xs text-muted">
                  {emptyHint}
                </td>
              </tr>
            ) : (
              capped.map((r) => {
                const selected = selectedKey != null && keyOf(r) === selectedKey
                return (
                  <tr
                    key={r.id}
                    onClick={onRowClick ? () => onRowClick(r) : undefined}
                    className={[
                      'border-t border-line transition-colors',
                      clickable ? 'cursor-pointer hover:bg-card-2/60' : '',
                      selected ? 'bg-gold/10' : '',
                    ].join(' ')}
                  >
                    {columns.map((c, i) => {
                      if (i === 0) {
                        return (
                          <td
                            key={c.label}
                            className={[
                              'px-4 py-3 max-w-[320px] truncate',
                              selected ? 'border-l-2 border-gold pl-3.5 font-semibold text-cream' : 'text-cream',
                            ].join(' ')}
                            title={r.nome}
                          >
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
                )
              })
            )}
            {sorted.length > MAX_ROWS && (
              <tr>
                <td colSpan={columns.length} className="px-4 py-2 text-center text-[11px] text-muted">
                  Mostrando {MAX_ROWS} de {sorted.length}. Ordene ou busque para refinar.
                </td>
              </tr>
            )}
          </tbody>
          {rows.length > 0 && (
            <tfoot className="sticky bottom-0 z-10">
              <tr className="border-t-2 border-line bg-card-2">
                {columns.map((c, i) => (
                  <td
                    key={c.label}
                    className="bg-card-2 px-4 py-3 text-[13px] font-bold whitespace-nowrap text-cream"
                  >
                    {i === 0
                      ? 'Total / Média'
                      : c.fmtAgg(aggregate(rows, (r) => c.get(r) as number, c.agg === 'avg' ? 'avg' : 'sum'))}
                  </td>
                ))}
              </tr>
            </tfoot>
          )}
        </table>
      </div>
    </div>
  )
}

const includes = (hay: string, needle: string) =>
  hay.toLowerCase().includes(needle.trim().toLowerCase())

export function TrafficTable({ rows }: { rows: TrafficRow[] }) {
  const [selCampanha, setSelCampanha] = useState<string | null>(null)
  const [selConjunto, setSelConjunto] = useState<string | null>(null)
  const [qCamp, setQCamp] = useState('')
  const [qConj, setQConj] = useState('')
  const [qAnun, setQAnun] = useState('')

  const { campanhas, conjuntos, anuncios } = useMemo(
    () => ({
      campanhas: rows.filter((r) => r.nivel === 'campanha'),
      conjuntos: rows.filter((r) => r.nivel === 'conjunto'),
      anuncios: rows.filter((r) => r.nivel === 'anuncio'),
    }),
    [rows]
  )

  const campanhasView = campanhas.filter((r) => includes(r.nome, qCamp))
  const conjuntosView = conjuntos
    .filter((r) => !selCampanha || r.campanha === selCampanha)
    .filter((r) => includes(r.nome, qConj))
  const anunciosView = anuncios
    .filter((r) => !selCampanha || r.campanha === selCampanha)
    .filter((r) => !selConjunto || r.conjunto === selConjunto)
    .filter((r) => includes(r.nome, qAnun))

  const onCampanha = (r: TrafficRow) => {
    if (selCampanha === r.campanha) {
      setSelCampanha(null)
      setSelConjunto(null)
    } else {
      setSelCampanha(r.campanha)
      setSelConjunto(null)
    }
  }
  const onConjunto = (r: TrafficRow) => {
    if (selConjunto === r.conjunto) {
      setSelConjunto(null)
    } else {
      setSelCampanha(r.campanha)
      setSelConjunto(r.conjunto)
    }
  }

  const hasFilter = selCampanha || selConjunto
  const clearFilter = () => {
    setSelCampanha(null)
    setSelConjunto(null)
  }

  return (
    <Panel className="p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <SectionTitle overline="Análise" title="Tráfego por campanha" />
        {hasFilter && (
          <button
            onClick={clearFilter}
            className="flex items-center gap-2 rounded-full border border-line bg-card-2 px-3 py-1 text-xs text-muted hover:text-cream"
          >
            <span className="text-cream">{selConjunto ?? selCampanha}</span>
            <span aria-hidden>✕ limpar</span>
          </button>
        )}
      </div>

      <div className="mb-5 grid grid-cols-1 gap-3 md:grid-cols-3">
        <SearchField label="Campanha" value={qCamp} onChange={setQCamp} />
        <SearchField label="Conjunto" value={qConj} onChange={setQConj} />
        <SearchField label="Anúncio" value={qAnun} onChange={setQAnun} />
      </div>

      <div className="flex flex-col gap-6">
        <MetricTable
          title="Campanhas"
          firstCol="Campanha"
          rows={campanhasView}
          selectedKey={selCampanha}
          onRowClick={onCampanha}
          keyOf={(r) => r.campanha}
          emptyHint="Nenhuma campanha no período."
        />
        <MetricTable
          title="Conjuntos"
          firstCol="Conjunto"
          rows={conjuntosView}
          selectedKey={selConjunto}
          onRowClick={onConjunto}
          keyOf={(r) => r.conjunto}
          emptyHint={selCampanha ? 'Nenhum conjunto nessa campanha.' : 'Clique numa campanha para focar, ou veja todos.'}
        />
        <MetricTable
          title="Anúncios"
          firstCol="Anúncio"
          rows={anunciosView}
          keyOf={(r) => r.anuncio}
          emptyHint={hasFilter ? 'Nenhum anúncio nesse filtro.' : 'Clique numa campanha/conjunto para focar, ou veja todos.'}
        />
      </div>
    </Panel>
  )
}
