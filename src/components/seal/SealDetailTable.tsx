import type { SealComprador } from '../../types'
import { Panel, SectionTitle } from '../ui/Panel'

const dash = (v: string | null) => (v && v.trim() ? v : '—')
/** 'quitou' = pagou complemento/integral; 'reserva' = só a taxa. */
const situacaoLabel = (s: string) => (s === 'quitou' ? 'Complemento' : 'Taxa')

const COLS = ['Tag', 'Data', 'Hora', 'Situação', 'Nome', 'Email', 'Campaign', 'Content', 'Term', 'Source', 'Medium', 'Página']

/**
 * Compradores SEAL, um por comprador. A RPC já prioriza a linha de
 * complemento/integral (esconde a taxa de quem já quitou). A coluna "Tag" é o
 * lançamento selecionado (o SEAL filtra por período, não tem tag na fonte).
 */
export function SealDetailTable({ rows, tag }: { rows: SealComprador[]; tag: string | null }) {
  return (
    <Panel className="p-5">
      <SectionTitle overline="SEAL" title="Compradores (taxa e complemento)" className="mb-4" />
      <div className="max-h-[420px] overflow-auto rounded-xl border border-line">
        <table className="w-full border-collapse whitespace-nowrap text-sm">
          <thead className="sticky top-0 z-10 bg-card-2 text-left text-[11px] uppercase tracking-[0.1em] text-muted">
            <tr>
              {COLS.map((h) => (
                <th key={h} className="bg-card-2 px-3 py-2.5 font-semibold">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr>
                <td colSpan={COLS.length} className="px-3 py-6 text-center text-xs text-muted">
                  Nenhum comprador SEAL no período.
                </td>
              </tr>
            ) : (
              rows.map((r, i) => (
                <tr key={`${r.email}-${i}`} className="border-t border-line text-cream">
                  <td className="px-3 py-2.5">{tag ?? '—'}</td>
                  <td className="px-3 py-2.5">{dash(r.data)}</td>
                  <td className="px-3 py-2.5">{r.hora ? r.hora.slice(0, 5) : '—'}</td>
                  <td className="px-3 py-2.5 font-medium">{situacaoLabel(r.situacao)}</td>
                  <td className="px-3 py-2.5">{dash(r.nome)}</td>
                  <td className="px-3 py-2.5 text-muted">{dash(r.email)}</td>
                  <td className="px-3 py-2.5">{dash(r.utmCampaign)}</td>
                  <td className="px-3 py-2.5">{dash(r.utmContent)}</td>
                  <td className="px-3 py-2.5">{dash(r.utmTerm)}</td>
                  <td className="px-3 py-2.5">{dash(r.utmSource)}</td>
                  <td className="px-3 py-2.5">{dash(r.utmMedium)}</td>
                  <td className="px-3 py-2.5">{dash(r.utmPagina)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </Panel>
  )
}
