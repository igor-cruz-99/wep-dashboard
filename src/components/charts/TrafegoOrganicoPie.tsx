import { PieChart, Pie, Cell, ResponsiveContainer } from 'recharts'
import type { TrafegoOrganico } from '../../types'
import { Panel } from '../ui/Panel'
import { formatInt, formatPct } from '../../utils/format'

const COR = { trafego: '#c9945f', organico: '#8fbf7f' }

/**
 * Pizza (donut) "Tráfego x Orgânico": leads pagos (utm_campaign preenchida) vs
 * orgânicos (utm_campaign vazia). Mostra contagem e % de cada lado.
 */
export function TrafegoOrganicoPie({ data }: { data: TrafegoOrganico }) {
  const total = data.trafego + data.organico
  const pct = (n: number) => (total > 0 ? (n / total) * 100 : 0)
  const fatias = [
    { key: 'trafego', label: 'Tráfego', value: data.trafego, color: COR.trafego },
    { key: 'organico', label: 'Orgânico', value: data.organico, color: COR.organico },
  ]

  return (
    <Panel className="flex h-full flex-col p-4">
      <h3 className="mb-2 text-sm font-semibold uppercase tracking-[0.08em] text-muted">
        Tráfego x Orgânico
      </h3>
      <div className="flex flex-1 items-center gap-4">
        <div className="relative h-36 w-36 shrink-0">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={fatias}
                dataKey="value"
                nameKey="label"
                cx="50%"
                cy="50%"
                innerRadius="62%"
                outerRadius="90%"
                paddingAngle={total > 0 ? 2 : 0}
                stroke="#191210"
                strokeWidth={1}
                isAnimationActive={false}
              >
                {fatias.map((f) => (
                  <Cell key={f.key} fill={f.color} />
                ))}
              </Pie>
            </PieChart>
          </ResponsiveContainer>
          <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-lg font-bold text-cream">{formatInt(total)}</span>
            <span className="text-[10px] uppercase tracking-wide text-muted">leads</span>
          </div>
        </div>

        <div className="flex flex-1 flex-col gap-2.5">
          {fatias.map((f) => (
            <div key={f.key} className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: f.color }} />
              <span className="text-sm text-cream">{f.label}</span>
              <span className="ml-auto text-sm font-semibold text-cream">{formatInt(f.value)}</span>
              <span className="w-12 text-right text-xs text-muted">{formatPct(pct(f.value))}</span>
            </div>
          ))}
        </div>
      </div>
    </Panel>
  )
}
