import type { FunnelStage } from '../../types'
import { formatBRL, formatInt } from '../../utils/format'

// Degradê creme: quase branco (topo/Investimento) → taupe (base/Vendas).
const TOP = { r: 245, g: 239, b: 224 } // #f5efe0
const BOTTOM = { r: 150, g: 132, b: 108 } // #96846c

function creamAt(t: number) {
  const r = Math.round(TOP.r + (BOTTOM.r - TOP.r) * t)
  const g = Math.round(TOP.g + (BOTTOM.g - TOP.g) * t)
  const b = Math.round(TOP.b + (BOTTOM.b - TOP.b) * t)
  return `rgb(${r} ${g} ${b})`
}

/**
 * Funil contínuo: cada degrau é um trapézio que vai da largura do topo até a
 * largura do topo do degrau seguinte — cantos alinhados na vertical.
 */
export function Funnel({ stages }: { stages: FunnelStage[] }) {
  const n = stages.length
  // Larguras (em % do container) do topo de cada degrau; TOP_MIN = base do último.
  const TOP_MAX = 100
  const TOP_MIN = 30
  const widthAt = (index: number) =>
    TOP_MAX - (index / n) * (TOP_MAX - TOP_MIN)

  return (
    <div className="flex w-full flex-col items-center gap-1">
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
          <div
            key={stage.label}
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
        )
      })}
    </div>
  )
}
