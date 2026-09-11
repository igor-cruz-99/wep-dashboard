import { useMemo, useState } from 'react'
import type { PaginaGaleria } from '../../types'
import { formatInt, formatPct2 } from '../../utils/format'
import { Panel } from '../ui/Panel'

/** "H1", "H2", "H1 · SS" — a variante de headline e se é a versão single shot. */
export const rotuloVariante = (p: PaginaGaleria) =>
  `${p.variante.toUpperCase()}${p.singleShot ? ' · SS' : ''}`

function Metrica({ label, valor }: { label: string; valor: string }) {
  return (
    <div className="min-w-0">
      <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-muted">{label}</p>
      <p className="truncate text-sm font-bold text-cream">{valor}</p>
    </div>
  )
}

function Card({ p, onAbrir }: { p: PaginaGaleria; onAbrir: () => void }) {
  const [erro, setErro] = useState(false)
  // Print de CELULAR na grade: o tráfego é da Meta e as vendas com
  // posicionamento identificado vieram todas de Feed/Reels/Stories. É a hero
  // que o lead vê. O desktop fica no popup, ao lado.
  const img = p.heroMobileUrl ?? p.heroUrl

  return (
    <button
      onClick={onAbrir}
      className="group flex flex-col overflow-hidden rounded-2xl border border-line bg-card text-left transition-colors hover:border-gold/50"
    >
      {/* object-top: a headline fica no alto da hero, é o que precisa aparecer. */}
      <div className="relative aspect-[3/4] w-full overflow-hidden bg-card-2">
        {img && !erro ? (
          <img
            src={img}
            alt={p.head}
            loading="lazy"
            className="h-full w-full object-cover object-top"
            onError={() => setErro(true)}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center px-4 text-center text-xs text-muted">
            {erro ? 'não foi possível carregar o print' : 'hero ainda não capturada'}
          </div>
        )}
        <span className="absolute left-2 top-2 rounded-full bg-black/70 px-2 py-0.5 text-[10px] font-semibold text-cream">
          {rotuloVariante(p)}
        </span>
      </div>

      <div className="flex flex-1 flex-col gap-3 p-3">
        {/* A head inteira, sem corte: ler a promessa sem clicar é o motivo da seção. */}
        <p className="text-sm font-semibold leading-snug text-cream">{p.head}</p>

        <div className="mt-auto grid grid-cols-2 gap-2 border-t border-line pt-2">
          <Metrica label="Page views" valor={formatInt(p.pageViews)} />
          <Metrica label="Vendas" valor={formatInt(p.vendas)} />
          <Metrica label="Checkouts" valor={formatInt(p.checkouts)} />
          <Metrica label="Visita → venda" valor={p.pageViews > 0 ? formatPct2(p.visitaVenda) : '—'} />
        </div>
      </div>
    </button>
  )
}

/**
 * As LPs da edição, agrupadas por LP para as variantes de headline ficarem lado
 * a lado — a pergunta da tela é qual promessa converte, e ela só se responde
 * comparando variantes da mesma página.
 *
 * Nada de destacar "a vencedora": no começo da edição cada variante tem uma ou
 * duas vendas, e a diferença entre elas é ruído. A tela mostra os números e o
 * tamanho da amostra; a conclusão fica com quem lê.
 */
export function PaginasGaleria({
  paginas,
  onAbrir,
  connectRate,
}: {
  paginas: PaginaGaleria[]
  onAbrir: (p: PaginaGaleria) => void
  /** Brutos da Meta no período, os mesmos que o funil usa. */
  connectRate?: { landingPageViews: number; linkCliques: number }
}) {
  const grupos = useMemo(() => {
    const m = new Map<string, PaginaGaleria[]>()
    for (const p of paginas) m.set(p.lp, [...(m.get(p.lp) ?? []), p])
    return [...m]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(
        ([lp, ps]) =>
          [
            lp,
            [...ps].sort(
              (a, b) => Number(a.singleShot) - Number(b.singleShot) || a.variante.localeCompare(b.variante)
            ),
          ] as const
      )
  }, [paginas])

  const tot = paginas.reduce(
    (s, p) => ({ pv: s.pv + p.pageViews, ck: s.ck + p.checkouts, vd: s.vd + p.vendas }),
    { pv: 0, ck: 0, vd: 0 }
  )

  // Connect rate oficial da Meta, a mesma conta do funil: visualizações da
  // página de destino ÷ cliques no link. É do período inteiro e não por página
  // porque a Meta entrega os dois números por anúncio, e a URL de destino de
  // cada anúncio não chega no banco — sem ela não há como saber para qual LP
  // cada clique foi. Sem clique, não há taxa: mostra "—" em vez de 0%.
  const taxaConnect =
    connectRate && connectRate.linkCliques > 0
      ? (connectRate.landingPageViews / connectRate.linkCliques) * 100
      : null

  return (
    <Panel className="p-5">
      <div className="mb-4 flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-muted">Páginas</p>
          <h2 className="text-lg font-bold text-cream">
            {paginas.length} {paginas.length === 1 ? 'página' : 'páginas'} da edição
          </h2>
          <p className="mt-0.5 text-sm text-muted">
            {formatInt(tot.pv)} page views · {formatInt(tot.ck)} checkouts · {formatInt(tot.vd)} vendas
          </p>
        </div>

        {connectRate && (
          <div className="rounded-2xl border border-gold/40 bg-gold/10 px-4 py-3 text-right">
            <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-muted">
              Connect rate do período
            </p>
            <p className="text-3xl font-bold leading-tight text-cream">
              {taxaConnect === null ? '—' : formatPct2(taxaConnect)}
            </p>
            <p className="text-[11px] text-muted">
              {formatInt(connectRate.landingPageViews)} visualizações ÷ {formatInt(connectRate.linkCliques)} cliques no link
            </p>
          </div>
        )}
      </div>

      {paginas.length === 0 ? (
        <p className="py-12 text-center text-sm text-muted">Nenhuma página no catálogo desta edição.</p>
      ) : (
        <div className="flex flex-col gap-6">
          {grupos.map(([lp, ps]) => (
            <section key={lp}>
              <p className="mb-3 text-[11px] font-semibold uppercase tracking-[0.2em] text-muted">
                {lp.toUpperCase()} · {ps.length} {ps.length === 1 ? 'variante' : 'variantes'}
              </p>
              <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
                {ps.map((p) => (
                  <Card key={p.pagina} p={p} onAbrir={() => onAbrir(p)} />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}
    </Panel>
  )
}
