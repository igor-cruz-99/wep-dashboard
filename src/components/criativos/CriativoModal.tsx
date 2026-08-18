import { useState } from 'react'
import type { CriativoGaleria } from '../../types'
import { formatBRL, formatInt } from '../../utils/format'

/**
 * Preview grande do criativo, aberto pelo clique no card da galeria.
 *
 * Diferente do popup da tabela de tráfego (AdThumbnailModal), este não busca
 * nada: a galeria já traz a mídia e as métricas, então abre instantâneo.
 * O vídeo só é carregado aqui — na grade ele é capa estática.
 */
export function CriativoModal({ c, onClose }: { c: CriativoGaleria; onClose: () => void }) {
  const [videoFalhou, setVideoFalhou] = useState(false)
  const mostraVideo = Boolean(c.videoUrl) && !videoFalhou

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      onClick={onClose}
    >
      <div
        className="flex max-h-[88vh] w-full max-w-3xl flex-col overflow-auto rounded-2xl border border-line bg-card p-5"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-muted">Anúncio</p>
            <h3 className="text-sm font-semibold text-cream" title={c.adName}>
              {c.adName}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="shrink-0 rounded-full border border-line bg-card-2 px-3 py-1 text-xs text-muted hover:text-cream"
          >
            ✕ fechar
          </button>
        </div>

        <div className="flex min-h-[240px] items-center justify-center rounded-xl border border-line bg-card-2">
          {mostraVideo ? (
            <video
              src={c.videoUrl as string}
              poster={c.url ?? undefined}
              controls
              playsInline
              preload="metadata"
              className="max-h-[58vh] w-full rounded-xl object-contain"
              onError={() => setVideoFalhou(true)}
            />
          ) : c.url ? (
            <img src={c.url} alt={c.adName} className="max-h-[58vh] w-full rounded-xl object-contain" />
          ) : (
            <p className="px-4 py-10 text-center text-xs text-muted">Sem mídia disponível.</p>
          )}
        </div>

        <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
          {[
            { label: 'Investimento', valor: formatBRL(c.investimento) },
            { label: 'Vendas', valor: formatInt(c.vendas) },
            { label: 'Checkouts', valor: formatInt(c.checkouts) },
            { label: 'CAC', valor: c.vendas > 0 ? formatBRL(c.cac) : '—' },
          ].map((m) => (
            <div key={m.label} className="rounded-xl border border-line bg-card-2 px-3 py-2">
              <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-muted">
                {m.label}
              </p>
              <p className="text-base font-bold text-cream">{m.valor}</p>
            </div>
          ))}
        </div>

        <p className="mt-3 text-[11px] text-muted">
          Somando {c.campanhas} {c.campanhas === 1 ? 'campanha' : 'campanhas'} no período. Para ver o
          desempenho separado por campanha, use a tabela de tráfego na etapa Padrão.
        </p>
      </div>
    </div>
  )
}
