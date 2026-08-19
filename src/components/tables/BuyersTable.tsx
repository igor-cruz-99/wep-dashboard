import { useMemo, useState } from 'react'
import type { Comprador } from '../../types'
import { formatBRL, formatInt } from '../../utils/format'
import { Panel, SectionTitle } from '../ui/Panel'

const DASH = '—'
const cell = (v: string | null) => (v && v.trim() !== '' ? v : DASH)

/** dd/mm a partir do 'YYYY-MM-DD' que vem da RPC, sem passar por Date (fuso). */
function diaMes(data: string | null) {
  if (!data) return DASH
  const [, m, d] = data.split('-')
  return d && m ? `${d}/${m}` : data
}

/** 'HH:MM' a partir do 'HH:MM:SS' do Postgres. */
const hhmm = (hora: string | null) => (hora ? hora.slice(0, 5) : '')

/**
 * A oferta é o valor pago — não existe campo de oferta na origem. Cores só
 * separam as faixas para o olho achar o grupo, sem afirmar qual é qual:
 * o valor cheio em creme, os descontos em âmbar, o simbólico em verde.
 */
function OfertaTag({ valor }: { valor: number }) {
  const cor = valor <= 5 ? '#9ed08b' : valor < 20 ? '#e8b05c' : '#f3ece3'
  return (
    <span
      className="inline-block rounded-full px-2 py-0.5 text-[11px] font-semibold whitespace-nowrap"
      style={{ color: cor, background: `${cor}1f` }}
    >
      {formatBRL(valor)}
    </span>
  )
}

/** Só o miolo do slug, que o prefixo se repete em toda linha e rouba a largura. */
function paginaCurta(pagina: string | null) {
  if (!pagina) return DASH
  return pagina.replace(/^\/(workshop|imersao)-estrategista-patrimonial-?/, '') || pagina
}

const COLUNAS = [
  'Data',
  'Comprador',
  'Oferta',
  'Página',
  'Origem',
  'Campanha',
  'Conjunto',
  'Anúncio',
  'Posicionamento',
]

/**
 * Uma linha por venda aprovada: quem comprou, por quanto, em que página e por
 * qual anúncio. Os blocos acima são todos agregados — este é o lugar de olhar
 * linha a linha quando um número agregado chama atenção.
 *
 * Só vendas APPROVED, o mesmo critério do funil: a contagem de linhas tem que
 * bater com a etapa Vendas logo acima.
 */
export function BuyersTable({ rows }: { rows: Comprador[] }) {
  const [q, setQ] = useState('')

  const view = useMemo(() => {
    const termo = q.trim().toLowerCase()
    if (!termo) return rows
    return rows.filter((r) =>
      [r.nome, r.email, r.pagina, r.utmCampaign, r.utmContent, r.utmSource, r.utmMedium]
        .some((v) => v?.toLowerCase().includes(termo))
    )
  }, [rows, q])

  const faturamento = view.reduce((s, r) => s + r.valor, 0)

  return (
    <Panel className="p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <SectionTitle overline="Vendas" title="Por compradores" />
          <p className="mt-0.5 text-sm text-muted">
            {formatInt(view.length)} {view.length === 1 ? 'venda' : 'vendas'} ·{' '}
            {formatBRL(faturamento)}
          </p>
        </div>
        <div className="flex w-full max-w-xs items-center gap-2 rounded-full border border-line bg-card-2 px-4 py-2">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" aria-hidden>
            <circle cx="11" cy="11" r="7" stroke="#a3907a" strokeWidth="2" />
            <path d="m20 20-3.5-3.5" stroke="#a3907a" strokeWidth="2" strokeLinecap="round" />
          </svg>
          <input
            placeholder="Buscar nome, email, página ou anúncio"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="w-full bg-transparent text-sm text-cream outline-none placeholder:text-muted"
          />
        </div>
      </div>

      {/* Rola nos dois eixos: são 9 colunas e o nome do anúncio é longo. */}
      <div className="max-h-[352px] overflow-auto rounded-xl border border-line">
        <table className="w-full border-collapse text-sm">
          <thead className="sticky top-0 z-10">
            <tr className="bg-card-2 text-left text-muted">
              {COLUNAS.map((h) => (
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
                <td colSpan={COLUNAS.length} className="px-4 py-8 text-center text-muted">
                  {q ? `Nenhum comprador com "${q}".` : 'Nenhuma venda no período.'}
                </td>
              </tr>
            ) : (
              view.map((r) => (
                <tr key={r.id} className="border-t border-line/60 text-cream">
                  <td className="px-4 py-2.5 whitespace-nowrap">
                    <p>{diaMes(r.data)}</p>
                    <p className="text-[11px] text-muted">{hhmm(r.hora)}</p>
                  </td>
                  {/* Nome e email empilhados: são dois campos que se leem juntos
                      e separá-los em colunas comeria a largura das UTMs. */}
                  <td className="px-4 py-2.5">
                    <p className="whitespace-nowrap">{cell(r.nome)}</p>
                    <p className="text-[11px] whitespace-nowrap text-muted">{cell(r.email)}</p>
                  </td>
                  <td className="px-4 py-2.5">
                    <OfertaTag valor={r.valor} />
                  </td>
                  <td
                    className="max-w-[200px] truncate px-4 py-2.5"
                    title={r.pagina ?? ''}
                  >
                    {paginaCurta(r.pagina)}
                  </td>
                  <td className="px-4 py-2.5 whitespace-nowrap">{cell(r.utmSource)}</td>
                  <td className="max-w-[260px] truncate px-4 py-2.5" title={r.utmCampaign ?? ''}>
                    {cell(r.utmCampaign)}
                  </td>
                  <td className="max-w-[200px] truncate px-4 py-2.5" title={r.utmMedium ?? ''}>
                    {cell(r.utmMedium)}
                  </td>
                  <td className="max-w-[300px] truncate px-4 py-2.5" title={r.utmContent ?? ''}>
                    {cell(r.utmContent)}
                  </td>
                  <td className="px-4 py-2.5 whitespace-nowrap">{cell(r.utmTerm)}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </Panel>
  )
}
