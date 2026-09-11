import { useState } from 'react'
import type { PaginaGaleria } from '../../types'
import { formatInt, formatPct2 } from '../../utils/format'
import { rotuloVariante } from './PaginasGaleria'

function Print({ titulo, url, alt }: { titulo: string; url: string | null; alt: string }) {
  const [erro, setErro] = useState(false)
  return (
    <div className="flex min-w-0 flex-col gap-2">
      <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-muted">{titulo}</p>
      <div className="flex min-h-[200px] items-start justify-center overflow-hidden rounded-xl border border-line bg-card-2">
        {url && !erro ? (
          <img
            src={url}
            alt={alt}
            className="max-h-[62vh] w-full object-contain object-top"
            onError={() => setErro(true)}
          />
        ) : (
          <p className="self-center px-4 py-10 text-center text-xs text-muted">
            {erro ? 'não foi possível carregar o print' : 'print ainda não capturado'}
          </p>
        )}
      </div>
    </div>
  )
}

/**
 * Popup da página: a hero no celular e no desktop, a head inteira e os números.
 *
 * Os prints foram tirados com GTM e Pixel bloqueados, então abrir este popup
 * não conta visita. O botão "Abrir página" é a exceção consciente: ele abre a
 * página real, e essa visita conta — por isso o aviso ao lado.
 */
export function PaginaModal({ p, onClose }: { p: PaginaGaleria; onClose: () => void }) {
  const taxa = (v: number, base: number) => (base > 0 ? formatPct2(v) : '—')

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4" onClick={onClose}>
      <div
        className="flex max-h-[90vh] w-full max-w-5xl flex-col overflow-auto rounded-2xl border border-line bg-card p-5"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-muted">
              {p.lp.toUpperCase()} · {rotuloVariante(p)}
            </p>
            <h3 className="text-base font-semibold leading-snug text-cream">{p.head}</h3>
          </div>
          <button
            onClick={onClose}
            className="shrink-0 rounded-full border border-line bg-card-2 px-3 py-1 text-xs text-muted hover:text-cream"
          >
            ✕ fechar
          </button>
        </div>

        {/* Celular estreito à esquerda, desktop largo à direita: cada print na
            proporção da própria tela, sem esticar nenhum. */}
        <div className="grid grid-cols-1 gap-4 md:grid-cols-[minmax(0,1fr)_minmax(0,2.4fr)]">
          <Print titulo="Celular" url={p.heroMobileUrl} alt={`${p.head} — celular`} />
          <Print titulo="Desktop" url={p.heroUrl} alt={`${p.head} — desktop`} />
        </div>

        <div className="mt-4 grid grid-cols-3 gap-3 sm:grid-cols-6">
          {[
            { label: 'Page views', valor: formatInt(p.pageViews) },
            { label: 'Checkouts', valor: formatInt(p.checkouts) },
            { label: 'Vendas', valor: formatInt(p.vendas) },
            { label: 'Visita → checkout', valor: taxa(p.visitaCheckout, p.pageViews) },
            { label: 'Visita → venda', valor: taxa(p.visitaVenda, p.pageViews) },
            { label: 'Checkout → venda', valor: taxa(p.checkoutVenda, p.checkouts) },
          ].map((m) => (
            <div key={m.label} className="rounded-xl border border-line bg-card-2 px-3 py-2">
              <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-muted">{m.label}</p>
              <p className="text-base font-bold text-cream">{m.valor}</p>
            </div>
          ))}
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-3">
          <a
            href={p.link}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-full border border-gold/50 bg-gold/15 px-4 py-1.5 text-xs font-semibold text-cream hover:bg-gold/25"
          >
            Abrir página ↗
          </a>
          <span className="text-[11px] text-muted">
            Abre a página real — essa visita conta no GA4 e no Pixel, ao contrário dos prints.
          </span>
        </div>
      </div>
    </div>
  )
}
