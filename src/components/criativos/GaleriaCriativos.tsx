import { useMemo, useState } from 'react'
import type { CriativoGaleria } from '../../types'
import { formatBRL, formatInt } from '../../utils/format'
import { Panel } from '../ui/Panel'

/** Meta de CAC do painel — colore o número para dar leitura imediata. */
const META_CAC = 450

type Ordem = 'gasto' | 'vendas' | 'cac'

const ORDENS: { id: Ordem; label: string }[] = [
  { id: 'gasto', label: 'Maior gasto' },
  { id: 'vendas', label: 'Mais vendas' },
  { id: 'cac', label: 'Melhor CAC' },
]

/**
 * Cor do CAC: verde abaixo da meta, âmbar até 1,5x, vermelho acima.
 * Sem venda não há CAC — fica neutro em vez de mentir um zero.
 */
function corCac(cac: number, vendas: number) {
  if (vendas === 0) return '#a3907a'
  if (cac <= META_CAC) return '#9ed08b'
  if (cac <= META_CAC * 1.5) return '#e6c35c'
  return '#e07b4f'
}

function Metrica({ label, valor, cor }: { label: string; valor: string; cor?: string }) {
  return (
    <div className="min-w-0">
      <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-muted">{label}</p>
      <p className="truncate text-sm font-bold" style={{ color: cor ?? '#f3ece3' }}>
        {valor}
      </p>
    </div>
  )
}

function Card({ c, onAbrir }: { c: CriativoGaleria; onAbrir: () => void }) {
  const [erro, setErro] = useState(false)
  const capa = c.url ?? null
  // Vídeo sem capa (o Drive tinha o mp4 mas não a imagem): renderiza o próprio
  // vídeo com preload="metadata", que baixa só o cabeçalho e mostra o primeiro
  // quadro. Sem isso os criativos de melhor CAC — que são justamente vídeos
  // puros — apareceriam como "sem mídia" na grade.
  const soVideo = !capa && Boolean(c.videoUrl)

  return (
    <button
      onClick={onAbrir}
      className="group flex flex-col overflow-hidden rounded-2xl border border-line bg-card text-left transition-colors hover:border-gold/50"
    >
      {/* 4:5 acomoda feed (1:1 e 4:5) sem tarja gigante; stories entra inteiro
          com object-contain em vez de ser cortado no meio. */}
      <div className="relative aspect-[4/5] w-full overflow-hidden bg-card-2">
        {capa && !erro ? (
          <img
            src={capa}
            alt={c.adName}
            loading="lazy"
            className="h-full w-full object-contain"
            onError={() => setErro(true)}
          />
        ) : soVideo && !erro ? (
          <video
            src={c.videoUrl as string}
            preload="metadata"
            muted
            playsInline
            className="h-full w-full object-contain"
            onError={() => setErro(true)}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center px-4 text-center text-xs text-muted">
            {erro ? 'não foi possível carregar a mídia' : 'sem mídia'}
          </div>
        )}
        {c.videoUrl && (
          <span className="absolute right-2 top-2 rounded-full bg-black/70 px-2 py-0.5 text-[10px] font-semibold text-cream">
            ▶ vídeo
          </span>
        )}
      </div>

      <div className="flex flex-1 flex-col gap-3 p-3">
        <p className="line-clamp-2 text-sm font-semibold text-cream" title={c.adName}>
          {c.adName}
        </p>

        {/* Vendas e CAC em destaque: a pergunta da tela é qual peça vende
            melhor, não qual gastou mais. */}
        <div className="mt-auto grid grid-cols-2 gap-2">
          <Metrica label="Vendas" valor={formatInt(c.vendas)} />
          <Metrica
            label="CAC"
            valor={c.vendas > 0 ? formatBRL(c.cac) : '—'}
            cor={corCac(c.cac, c.vendas)}
          />
        </div>

        <div className="flex items-center justify-between border-t border-line pt-2 text-[13px] text-muted">
          <span>{formatBRL(c.investimento)}</span>
          <span>
            {c.campanhas} {c.campanhas === 1 ? 'campanha' : 'campanhas'}
          </span>
        </div>
      </div>
    </button>
  )
}

export function GaleriaCriativos({
  criativos,
  onAbrir,
}: {
  criativos: CriativoGaleria[]
  onAbrir: (c: CriativoGaleria) => void
}) {
  const [busca, setBusca] = useState('')
  const [ordem, setOrdem] = useState<Ordem>('gasto')

  const lista = useMemo(() => {
    const q = busca.trim().toLowerCase()
    const filtrada = q ? criativos.filter((c) => c.adName.toLowerCase().includes(q)) : criativos
    const arr = [...filtrada]
    if (ordem === 'vendas') arr.sort((a, b) => b.vendas - a.vendas || b.investimento - a.investimento)
    // Sem venda não tem CAC: esses vão para o fim em vez de liderar com zero.
    else if (ordem === 'cac')
      arr.sort((a, b) => {
        if (a.vendas === 0 && b.vendas === 0) return b.investimento - a.investimento
        if (a.vendas === 0) return 1
        if (b.vendas === 0) return -1
        return a.cac - b.cac
      })
    else arr.sort((a, b) => b.investimento - a.investimento)
    return arr
  }, [criativos, busca, ordem])

  const totalGasto = lista.reduce((s, c) => s + c.investimento, 0)
  const totalVendas = lista.reduce((s, c) => s + c.vendas, 0)

  return (
    <Panel className="p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-muted">Criativos</p>
          <h2 className="text-lg font-bold text-cream">
            {lista.length} {lista.length === 1 ? 'anúncio' : 'anúncios'} no período
          </h2>
          <p className="mt-0.5 text-sm text-muted">
            {formatBRL(totalGasto)} investidos · {formatInt(totalVendas)} vendas
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <div className="flex items-center gap-2 rounded-full border border-line bg-card-2 px-4 py-2">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" aria-hidden>
              <circle cx="11" cy="11" r="7" stroke="#a3907a" strokeWidth="2" />
              <path d="m20 20-3.5-3.5" stroke="#a3907a" strokeWidth="2" strokeLinecap="round" />
            </svg>
            <input
              placeholder="Pesquisar anúncio"
              value={busca}
              onChange={(e) => setBusca(e.target.value)}
              className="w-44 bg-transparent text-sm text-cream outline-none placeholder:text-muted"
            />
          </div>

          <div className="flex overflow-hidden rounded-full border border-line">
            {ORDENS.map((o) => (
              <button
                key={o.id}
                onClick={() => setOrdem(o.id)}
                className={`px-3 py-2 text-xs transition-colors ${
                  ordem === o.id ? 'bg-gold/20 text-cream' : 'bg-card-2 text-muted hover:text-cream'
                }`}
              >
                {o.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {lista.length === 0 ? (
        <p className="py-12 text-center text-sm text-muted">
          {busca
            ? `Nenhum anúncio com "${busca}".`
            : 'Nenhum criativo com mídia e investimento no período.'}
        </p>
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
          {lista.map((c) => (
            <Card key={c.adName} c={c} onAbrir={() => onAbrir(c)} />
          ))}
        </div>
      )}
    </Panel>
  )
}
