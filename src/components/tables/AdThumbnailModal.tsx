import { useEffect, useState } from 'react'
import { fetchAdThumbnail } from '../../lib/queries'
import type { TrafficRow } from '../../types'

interface AdThumbnailModalProps {
  row: TrafficRow
  onClose: () => void
}

// TODO (quando o n8n marcar falha permanente — anúncio excluído/inacessível
// na Meta — com um campo tipo sync_status/motivo em core.ads_thumbnails):
// adicionar status 'excluido' aqui e mostrar "Anúncio excluído" no popup,
// em vez do genérico "sem preview disponível" do estado 'vazio'.
type Status = 'loading' | 'ok' | 'vazio' | 'erro'

/** Popup com a imagem/capa do anúncio clicado na tabela de tráfego. */
export function AdThumbnailModal({ row, onClose }: AdThumbnailModalProps) {
  const [status, setStatus] = useState<Status>('loading')
  const [url, setUrl] = useState<string | null>(null)

  useEffect(() => {
    let cancelado = false
    setStatus('loading')
    setUrl(null)

    if (!row.adId) {
      setStatus('vazio')
      return
    }

    fetchAdThumbnail(row.adId)
      .then((r) => {
        if (cancelado) return
        if (!r?.url) setStatus('vazio')
        else {
          setUrl(r.url)
          setStatus('ok')
        }
      })
      .catch(() => {
        if (!cancelado) setStatus('erro')
      })

    return () => {
      cancelado = true
    }
  }, [row.adId])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[85vh] w-full max-w-lg overflow-auto rounded-2xl border border-line bg-card p-5"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-muted">
              Anúncio
            </p>
            <h3 className="truncate text-sm font-semibold text-cream" title={row.nome}>
              {row.nome}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="shrink-0 rounded-full border border-line bg-card-2 px-3 py-1 text-xs text-muted hover:text-cream"
          >
            ✕ fechar
          </button>
        </div>

        <div className="flex min-h-[220px] items-center justify-center rounded-xl border border-line bg-card-2">
          {status === 'loading' && (
            <p className="text-xs text-muted">Carregando preview…</p>
          )}
          {status === 'vazio' && (
            <p className="max-w-xs px-4 text-center text-xs text-muted">
              Sem preview disponível para este anúncio.
            </p>
          )}
          {status === 'erro' && (
            <p className="max-w-xs px-4 text-center text-xs text-muted">
              Não foi possível carregar o preview agora.
            </p>
          )}
          {status === 'ok' && url && (
            <img
              src={url}
              alt={row.nome}
              className="max-h-[60vh] w-full rounded-xl object-contain"
              onError={() => setStatus('erro')}
            />
          )}
        </div>
      </div>
    </div>
  )
}
