import type { SealComprador } from '../../types'
import { formatBRL } from '../../utils/format'
import { Panel, SectionTitle } from '../ui/Panel'

const dash = (v: string | null) => (v && v.trim() ? v : '—')
/**
 * 'completa' = pagou o SEAL inteiro no período (>= R$ 3.000, somando pedidos);
 * 'complemento' = pagou só uma parte. A classificação vem do VALOR, não do
 * nome do produto — na origem tudo se chama "SEAL" hoje (ver sql/77).
 */
const situacaoLabel = (s: string) => (s === 'completa' ? 'Completa' : 'Complemento')

// "Valor pago" logo depois de "Situação": é o número que define a situação,
// então os dois se leem juntos.
const COLS = ['Tag', 'Data', 'Hora', 'Situação', 'Valor pago', 'Nome', 'Email', 'Campaign', 'Content', 'Term', 'Source', 'Medium', 'Página']

/**
 * Compradores SEAL, um por comprador. A RPC mostra a linha de MAIOR valor
 * cobrado — a compra que define o aluno. A coluna "Tag" é o lançamento
 * selecionado (o SEAL filtra por período, não tem tag na fonte).
 */
export function SealDetailTable({ rows, tag }: { rows: SealComprador[]; tag: string | null }) {
  return (
    <Panel className="p-5">
      <SectionTitle overline="SEAL" title="Compradores (completa e complemento)" className="mb-4" />
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
                  {/* Total do aluno no período, não o valor da linha exibida.
                      Quando somou mais de um pedido, avisa — senão o número
                      pareceria não bater com a compra mostrada ao lado. */}
                  <td className="px-3 py-2.5 font-medium">
                    {formatBRL(r.valorPago)}
                    {r.pedidos > 1 && (
                      <span className="ml-1 text-[10px] font-normal text-muted">
                        {r.pedidos} pedidos
                      </span>
                    )}
                  </td>
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
