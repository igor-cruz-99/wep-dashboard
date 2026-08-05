import type { FunnelStage } from '../../types'
import { formatBRL, formatDec1, formatInt, formatPct2 } from '../../utils/format'

// Degradê creme: quase branco (topo/Investimento) → taupe (base/Vendas).
const TOP = { r: 245, g: 239, b: 224 } // #f5efe0
const BOTTOM = { r: 150, g: 132, b: 108 } // #96846c

function creamAt(t: number) {
  const r = Math.round(TOP.r + (BOTTOM.r - TOP.r) * t)
  const g = Math.round(TOP.g + (BOTTOM.g - TOP.g) * t)
  const b = Math.round(TOP.b + (BOTTOM.b - TOP.b) * t)
  return `rgb(${r} ${g} ${b})`
}

/** Métrica derivada exibida numa caixa sobreposta à borda entre dois degraus. */
interface OverlayMetric {
  label: string
  /** Índice do degrau em cuja borda inferior a caixa é ancorada. */
  boundary: number
  side: 'left' | 'right'
  /** Já formatado, ou null quando o denominador é zero (mostra "—"). */
  text: string | null
}

export type FunnelVariant = 'meteorico' | 'padrao' | 'seal'

/** Divisão protegida: sem denominador não há métrica (≠ métrica igual a zero). */
const safe = (a: number, b: number) => (b > 0 ? a / b : null)
const fmt = (v: number | null, f: (n: number) => string) => (v === null ? null : f(v))

/**
 * Funil contínuo: cada degrau é um trapézio que vai da largura do topo até a
 * largura do topo do degrau seguinte — cantos alinhados na vertical.
 * Sobre as bordas entre os degraus flutuam as métricas derivadas (CPM, CTR, …),
 * alternando esquerda/direita.
 *
 * As etapas já vêm reduzidas por etapa (Meteórico sem Checkouts; Padrão sem
 * Leads). As métricas laterais se ancoram pelo NOME da etapa, então acompanham
 * a lista recebida.
 */
export function Funnel({
  stages,
  cac,
  variant = 'meteorico',
  landingPageViews,
  linkCliques,
}: {
  stages: FunnelStage[]
  cac?: number
  variant?: FunnelVariant
  /** Connect Rate = landingPageViews ÷ linkCliques × 100 (métrica oficial da Meta). */
  landingPageViews?: number
  linkCliques?: number
}) {
  const n = stages.length
  // Larguras (em % do container) do topo de cada degrau; TOP_MIN = base do último.
  const TOP_MAX = 100
  const TOP_MIN = 30
  const widthAt = (index: number) =>
    TOP_MAX - (index / n) * (TOP_MAX - TOP_MIN)

  const metrics = buildMetrics(stages, cac, variant, landingPageViews, linkCliques)

  return (
    <div className="flex w-full flex-col items-center gap-1 px-7">
      {stages.map((stage, i) => {
        const t = i / (n - 1)
        const topW = widthAt(i)
        const botW = widthAt(i + 1)
        // Cantos como % da largura total (elemento ocupa 100% do container).
        const tl = (100 - topW) / 2
        const tr = (100 + topW) / 2
        const bl = (100 - botW) / 2
        const br = (100 + botW) / 2
        const value =
          stage.format === 'brl' ? formatBRL(stage.value) : formatInt(stage.value)
        return (
          // Wrapper posicionado: o degrau tem clip-path, então as caixas não
          // podem ser filhas dele (seriam recortadas junto).
          <div key={stage.label} className="relative w-full">
            <div
              className="flex w-full flex-col items-center justify-center py-3.5 text-center"
              style={{
                background: creamAt(t),
                color: '#2b2014',
                clipPath: `polygon(${tl}% 0, ${tr}% 0, ${br}% 100%, ${bl}% 100%)`,
              }}
            >
              <span className="text-[11px] font-extrabold uppercase tracking-[0.15em] opacity-80">
                {stage.label}
              </span>
              <span className="text-xl font-bold leading-tight">{value}</span>
            </div>

            {metrics
              .filter((m) => m.boundary === i)
              .map((m) => (
                <div
                  key={m.label}
                  className="absolute bottom-0 z-10 -translate-x-1/2 translate-y-1/2 whitespace-nowrap rounded-md px-2.5 py-1 text-center shadow-md shadow-black/30"
                  style={{
                    // Creme do topo do funil (mesma cor da camada "Investimento").
                    background: `rgb(${TOP.r} ${TOP.g} ${TOP.b} / 0.9)`,
                    color: '#2b2014',
                    left: `${m.side === 'left' ? bl : br}%`,
                  }}
                >
                  <span className="block text-[9px] font-semibold uppercase tracking-wider opacity-70">
                    {m.label}
                  </span>
                  <span className="block text-xs font-bold leading-tight">
                    {m.text ?? '—'}
                  </span>
                </div>
              ))}
          </div>
        )
      })}
    </div>
  )
}

/**
 * Métricas laterais, ancoradas pelo NOME da etapa (boundary = índice dela na
 * lista recebida). Assim funciona em qualquer variante:
 *  - Meteórico: … Page Views → Leads (CPL) → Vendas (CAC).
 *  - Padrão:    … Page Views → Checkouts (Conversão Checkout) → Vendas (CAC).
 * CPC foi removido (não faz parte destas visões). Connect Rate = Connect
 * Rate OFICIAL da Meta (landing_page_views ÷ link_cliques) — não usa as
 * etapas Cliques/Page Views do funil (que mistura GA4 com Meta e conta TODO
 * tráfego, não só o pago; nesse caso passava de 100% com frequência quando
 * havia muito tráfego orgânico/direto). Por isso entra como parâmetro à
 * parte — ver memória do projeto pra histórico da decisão.
 */
function buildMetrics(
  stages: FunnelStage[],
  cac: number | undefined,
  variant: FunnelVariant,
  landingPageViews?: number,
  linkCliques?: number
): OverlayMetric[] {
  const at = (label: string) => Number(stages.find((s) => s.label === label)?.value ?? 0)
  const idx = (label: string) => stages.findIndex((s) => s.label === label)

  const investimento = at('Investimento')
  const alcance = at('Alcance')
  const impressoes = at('Impressões')
  const cliques = at('Cliques')
  const pageViews = at('Page Views')
  const leads = at('Leads')
  const checkouts = at('Checkouts')
  const vendas = at('Vendas')

  const pctOf = (v: number | null) => (v === null ? null : v * 100)

  const out: OverlayMetric[] = []
  const push = (label: string, anchor: string, side: 'left' | 'right', text: string | null) => {
    const b = idx(anchor)
    if (b >= 0) out.push({ label, boundary: b, side, text })
  }

  push('Frequência', 'Alcance', 'right', fmt(safe(impressoes, alcance), formatDec1))
  push('CPM', 'Impressões', 'left', fmt(safe(investimento * 1000, impressoes), formatBRL))
  push('CTR', 'Impressões', 'right', fmt(pctOf(safe(cliques, impressoes)), formatPct2))
  push('Connect Rate', 'Cliques', 'right', fmt(pctOf(safe(landingPageViews ?? 0, linkCliques ?? 0)), formatPct2))
  // CPC: só no Padrão (pedido específico dessa visão).
  if (variant === 'padrao') {
    push('CPC', 'Cliques', 'left', fmt(safe(investimento, cliques), formatBRL))
  }
  push('CPLV', 'Page Views', 'left', fmt(safe(investimento, pageViews), formatBRL))
  // Conversão Página: Meteórico = leads ÷ page views; Padrão = vendas ÷ page views.
  const convNum = variant === 'padrao' ? vendas : leads
  push('Conversão Página', 'Page Views', 'right', fmt(pctOf(safe(convNum, pageViews)), formatPct2))

  if (variant === 'padrao') {
    push('Conversão Checkout', 'Checkouts', 'left', fmt(pctOf(safe(vendas, checkouts)), formatPct2))
    push('CAC', 'Checkouts', 'right', cac && cac > 0 ? formatBRL(cac) : null)
  } else {
    push('CPL', 'Leads', 'left', fmt(safe(investimento, leads), formatBRL))
    push('CAC', 'Leads', 'right', cac && cac > 0 ? formatBRL(cac) : null)
  }

  return out
}
