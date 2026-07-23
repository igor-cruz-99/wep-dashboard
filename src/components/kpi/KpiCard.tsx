import type { Kpi } from '../../types'
import { metaColor, metaScore } from '../../utils/metaColor'
import { formatBRL, formatInt, formatPct } from '../../utils/format'
import { Panel } from '../ui/Panel'

function formatValue(value: number, format: Kpi['format']) {
  if (format === 'brl') return formatBRL(value)
  if (format === 'pct') return formatPct(value)
  return formatInt(value)
}

/** Setinha de tendência: sobe quando a métrica vai bem, desce quando vai mal. */
export function TrendArrow({ up, color }: { up: boolean; color: string }) {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d={up ? 'M3 17 9 11l4 4 8-8M15 7h6v6' : 'M3 7l6 6 4-4 8 8M15 17h6v-6'}
        stroke={color}
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

/**
 * Cartão de KPI (estética dark):
 *  - rótulo no topo, valor grande, "Meta X" abaixo
 *  - canto sup. direito: seta + %meta na cor do desempenho
 *  - glow em degradê da mesma cor no canto do card
 *  - barra de progresso (verde-claro→verde-escuro quando positivo)
 */
export function KpiCard({ kpi }: { kpi: Kpi }) {
  // Sem meta (ex.: CPL): card mostra só o valor, sem %meta/seta/barra.
  const hasMeta = typeof kpi.meta === 'number' && kpi.meta > 0
  const pct = hasMeta ? (kpi.value / (kpi.meta as number)) * 100 : 0
  const score = metaScore(pct, kpi.direction)
  const color = metaColor(pct, kpi.direction)
  const good = score >= 0.5

  const barGradient = good
    ? 'linear-gradient(90deg, #9ed08b, #4f8a3d)' // verde claro → verde escuro
    : 'linear-gradient(90deg, #e07b4f, #e6c35c)' // laranja → amarelo

  return (
    <Panel
      className="relative overflow-hidden px-4 pb-4 pt-3"
      style={
        hasMeta
          ? { backgroundImage: `radial-gradient(120% 90% at 100% 0%, ${color}2e 0%, transparent 55%)` }
          : undefined
      }
    >
      <div className="flex items-start justify-between gap-2">
        <span className="text-[11px] font-semibold uppercase tracking-[0.15em] text-muted">
          {kpi.label}
        </span>
        {hasMeta && (
          <span className="flex items-center gap-1 text-xs font-bold" style={{ color }}>
            <TrendArrow up={good} color={color} />
            {formatPct(pct)}
          </span>
        )}
      </div>

      <p className="mt-2 text-3xl font-bold tracking-tight text-cream">
        {formatValue(kpi.value, kpi.format)}
      </p>

      {hasMeta && (
        <>
          <p className="mt-1 text-xs text-muted">Meta {formatValue(kpi.meta as number, kpi.format)}</p>
          <div className="mt-3 h-1.5 w-full overflow-hidden rounded-full bg-card-2">
            <div
              className="h-full rounded-full"
              style={{ width: `${Math.min(100, Math.max(2, pct))}%`, background: barGradient }}
            />
          </div>
        </>
      )}
    </Panel>
  )
}
