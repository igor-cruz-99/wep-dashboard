import type { CplOrigem } from '../../types'
import { Panel } from '../ui/Panel'
import { formatBRL, formatInt } from '../../utils/format'

/**
 * Card "CPL por origem": compara o CPL das Páginas vs Formulário nativo.
 * Sob cada CPL, o detalhe (leads · investimento). Sem leads → "—".
 */
export function CplOrigemCard({ data }: { data: CplOrigem }) {
  const linhas = [
    { label: 'Páginas', ...data.pagina },
    { label: 'Forms nativo', ...data.nativo },
  ]

  return (
    <Panel className="flex h-full flex-col p-4">
      <h3 className="mb-1 text-sm font-semibold uppercase tracking-[0.08em] text-muted">
        CPL por origem
      </h3>
      <div className="flex flex-1 flex-col justify-center divide-y divide-line">
        {linhas.map((l) => (
          <div key={l.label} className="flex items-center justify-between gap-3 py-3">
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-wide text-cream">{l.label}</p>
              <p className="text-[11px] text-muted/70">
                {formatInt(l.leads)} {l.leads === 1 ? 'lead' : 'leads'} · {formatBRL(l.investimento)}
              </p>
            </div>
            <p className="shrink-0 text-2xl font-bold tracking-tight text-cream">
              {l.leads > 0 ? formatBRL(l.cpl) : '—'}
            </p>
          </div>
        ))}
      </div>
    </Panel>
  )
}
