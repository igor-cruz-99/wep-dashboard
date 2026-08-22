import { useMemo, useState } from 'react'
import type { SealComprador } from '../../types'
import { Panel, SectionTitle } from '../ui/Panel'

const DASH = '—'
const cell = (v: string | null) => (v && v.trim() !== '' ? v : DASH)

/**
 * Etiqueta colorida da situação, no padrão dos cards. A situação vem do valor
 * pago no período (>= R$ 3.000 é completa), não do nome do produto — ver
 * sql/77.
 */
function SituacaoTag({ situacao }: { situacao: string }) {
  const completa = situacao === 'completa'
  return (
    <span
      className="inline-block rounded-full px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider"
      style={{
        color: completa ? '#9ed08b' : '#e8b05c',
        background: completa ? '#9ed08b1f' : '#e8b05c1f',
      }}
    >
      {completa ? 'Completa' : 'Complemento'}
    </span>
  )
}

/**
 * Tabela de compradores SEAL: nome, email, situação e UTMs (roadmap item 2).
 * UTMs vêm da venda, com fallback pelo email no pré-checkout (resolvido na RPC).
 */
export function SealBuyersTable({ rows }: { rows: SealComprador[] }) {
  const [q, setQ] = useState('')

  const view = useMemo(() => {
    const term = q.trim().toLowerCase()
    if (!term) return rows
    return rows.filter((r) =>
      [r.nome, r.email, r.utmCampaign, r.utmSource]
        .some((v) => v?.toLowerCase().includes(term))
    )
  }, [rows, q])

  return (
    <Panel className="p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <SectionTitle overline="SEAL" title="Compradores" />
        <div className="flex w-full max-w-xs items-center gap-2 rounded-full border border-line bg-card-2 px-4 py-2">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" aria-hidden>
            <circle cx="11" cy="11" r="7" stroke="#a3907a" strokeWidth="2" />
            <path d="m20 20-3.5-3.5" stroke="#a3907a" strokeWidth="2" strokeLinecap="round" />
          </svg>
          <input
            placeholder="Buscar nome, email ou campanha"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="w-full bg-transparent text-sm text-cream outline-none placeholder:text-muted"
          />
        </div>
      </div>

      <div className="max-h-[352px] overflow-auto rounded-xl border border-line">
        <table className="w-full border-collapse text-sm">
          <thead className="sticky top-0 z-10">
            <tr className="bg-card-2 text-left text-muted">
              {['Nome', 'Email', 'Situação', 'UTM Source', 'UTM Campaign', 'UTM Medium', 'UTM Content'].map((h) => (
                <th
                  key={h}
                  className="bg-card-2 px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.12em] whitespace-nowrap"
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {view.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-muted">
                  Nenhum comprador SEAL.
                </td>
              </tr>
            ) : (
              view.map((r) => (
                <tr key={r.email} className="border-t border-line/60 text-cream">
                  <td className="px-4 py-2.5 whitespace-nowrap">{cell(r.nome)}</td>
                  <td className="px-4 py-2.5 whitespace-nowrap text-muted">{r.email}</td>
                  <td className="px-4 py-2.5 whitespace-nowrap"><SituacaoTag situacao={r.situacao} /></td>
                  <td className="px-4 py-2.5 whitespace-nowrap">{cell(r.utmSource)}</td>
                  <td className="max-w-[280px] truncate px-4 py-2.5" title={r.utmCampaign ?? ''}>{cell(r.utmCampaign)}</td>
                  <td className="px-4 py-2.5 whitespace-nowrap">{cell(r.utmMedium)}</td>
                  <td className="max-w-[280px] truncate px-4 py-2.5" title={r.utmContent ?? ''}>{cell(r.utmContent)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </Panel>
  )
}
