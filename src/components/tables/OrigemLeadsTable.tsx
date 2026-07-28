import type { OrigemLeadRow } from '../../types'
import { Panel } from '../ui/Panel'
import { formatInt, formatPct } from '../../utils/format'

/** Encurta o caminho da página pra um rótulo legível (tira o prefixo comum). */
function pretty(o: string): string {
  if (!o.startsWith('/')) return o // "Formulário nativo", "(sem origem)"
  return o.replace('/imersao-engenheiro-patrimonial-', '')
}

/**
 * Tabela "Origem dos Leads": de qual página/forms cada lead veio, quantos são
 * e o % sobre o total. A barra é proporcional ao maior valor (leitura rápida).
 */
export function OrigemLeadsTable({ rows }: { rows: OrigemLeadRow[] }) {
  const max = Math.max(1, ...rows.map((r) => r.leads))
  const total = rows.reduce((s, r) => s + r.leads, 0)

  return (
    <Panel className="p-5">
      <div className="mb-4 flex items-baseline justify-between">
        <h3 className="text-sm font-semibold uppercase tracking-[0.08em] text-muted">
          Origem dos Leads
        </h3>
        <span className="text-xs text-muted">{formatInt(total)} leads</span>
      </div>

      {rows.length === 0 ? (
        <p className="py-6 text-center text-sm text-muted">Sem leads no período.</p>
      ) : (
        <div className="flex flex-col gap-2.5">
          {rows.map((r) => (
            <div key={r.origem} className="flex items-center gap-3">
              <span
                className="w-32 shrink-0 truncate text-sm text-cream"
                title={r.origem}
              >
                {pretty(r.origem)}
              </span>
              <div className="h-2 flex-1 overflow-hidden rounded-full bg-card-2">
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${(r.leads / max) * 100}%`,
                    background: 'linear-gradient(90deg,#c9945f,#a3763f)',
                  }}
                />
              </div>
              <span className="w-12 shrink-0 text-right text-sm font-semibold text-cream">
                {formatInt(r.leads)}
              </span>
              <span className="w-14 shrink-0 text-right text-xs text-muted">
                {formatPct(r.pct)}
              </span>
            </div>
          ))}
        </div>
      )}
    </Panel>
  )
}
