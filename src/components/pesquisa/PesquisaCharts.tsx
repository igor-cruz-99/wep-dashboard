import {
  Bar,
  BarChart,
  Cell,
  LabelList,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import type { PerfilDatum, PesquisaPerfil } from '../../types'
import { formatInt, formatPct } from '../../utils/format'
import { metaColor, metaScore } from '../../utils/metaColor'
import { TrendArrow } from '../kpi/KpiCard'
import { Panel, SectionTitle } from '../ui/Panel'

/**
 * Paleta categórica quente, calibrada para o fundo escuro do painel.
 * Usada nas fatias de pizza/rosca (as barras usam um tom só).
 */
const PALETTE = [
  '#e8b05c', // gold
  '#c9945f', // caramelo
  '#d9c9a8', // creme-tan
  '#a3907a', // taupe
  '#b5764a', // terracota
  '#8a6d4b', // marrom
  '#efd9a6', // creme claro
  '#7c5a3a', // marrom escuro
]

const BAR_COLOR = '#c9945f'
const AXIS_TICK = { fontSize: 11, fill: '#a3907a' }

const tooltipStyle = {
  borderRadius: 10,
  border: '1px solid #3a2d21',
  background: '#211a13',
  color: '#f2e9d8',
  fontSize: 12,
}

/** Tooltip: "Categoria — N (X%)". Total do denominador vem por fora. */
function makeTooltipFormatter(total: number) {
  return (value: unknown, _name: unknown, item: { payload?: PerfilDatum }) => {
    const n = Number(value)
    const pct = total > 0 ? Math.round((n / total) * 100) : 0
    return [`${formatInt(n)} (${pct}%)`, item.payload?.categoria ?? '']
  }
}

function EmptyState() {
  return (
    <div className="flex h-full items-center justify-center text-sm text-muted">
      Sem respostas no período.
    </div>
  )
}

function ChartFrame({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <Panel className="flex flex-col p-4">
      <h3 className="mb-3 text-[11px] font-semibold uppercase tracking-[0.15em] text-muted">
        {title}
      </h3>
      <div className="h-60">{children}</div>
    </Panel>
  )
}

/** Barras horizontais — bom para categorias de rótulo longo (renda, profissão). */
function HBar({ data }: { data: PerfilDatum[] }) {
  if (data.length === 0) return <EmptyState />
  const total = data.reduce((s, d) => s + d.total, 0)
  return (
    <ResponsiveContainer width="100%" height="100%">
      {/* right maior: abre espaço para o rótulo "valor (%)" na ponta da barra. */}
      <BarChart data={data} layout="vertical" margin={{ top: 4, right: 56, bottom: 4, left: 8 }}>
        <XAxis type="number" tick={AXIS_TICK} tickLine={false} axisLine={{ stroke: '#3a2d21' }} allowDecimals={false} />
        <YAxis
          type="category"
          dataKey="categoria"
          tick={AXIS_TICK}
          tickLine={false}
          axisLine={{ stroke: '#3a2d21' }}
          width={130}
        />
        <Tooltip contentStyle={tooltipStyle} cursor={{ fill: '#f2e9d811' }} formatter={makeTooltipFormatter(total)} />
        <Bar dataKey="total" fill={BAR_COLOR} radius={[0, 3, 3, 0]} isAnimationActive={false}>
          <LabelList
            dataKey="total"
            position="right"
            offset={6}
            fontSize={10}
            fill="#f2e9d8"
            formatter={(v: unknown) => {
              const n = Number(v)
              const pct = total > 0 ? Math.round((n / total) * 100) : 0
              return `${formatInt(n)} (${pct}%)`
            }}
          />
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  )
}

/** Props que o Recharts passa ao renderer de label do Pie (subconjunto usado). */
interface PieLabelProps {
  cx?: number
  cy?: number
  midAngle?: number
  outerRadius?: number
  percent?: number
  name?: string
}

/**
 * Label externo com linha-guia (leader line): um traço sai da fatia, dobra na
 * horizontal e escreve "categoria" + "%". Desenho a linha e o texto juntos
 * (mesmo <g>) para os dois ficarem sempre alinhados.
 */
function renderLeaderLabel(p: PieLabelProps) {
  const RAD = Math.PI / 180
  const cx = p.cx ?? 0
  const cy = p.cy ?? 0
  const outerRadius = p.outerRadius ?? 0
  const cos = Math.cos(-(p.midAngle ?? 0) * RAD)
  const sin = Math.sin(-(p.midAngle ?? 0) * RAD)
  const right = cos >= 0
  // Início na borda da fatia → cotovelo um pouco fora → trecho horizontal.
  const sx = cx + outerRadius * cos
  const sy = cy + outerRadius * sin
  const mx = cx + (outerRadius + 12) * cos
  const my = cy + (outerRadius + 12) * sin
  const ex = mx + (right ? 1 : -1) * 14
  const tx = ex + (right ? 4 : -4)
  const anchor = right ? 'start' : 'end'
  const pct = Math.round((p.percent ?? 0) * 100)
  return (
    <g>
      <polyline points={`${sx},${sy} ${mx},${my} ${ex},${my}`} stroke="#a3907a" strokeWidth={1} fill="none" />
      <text x={tx} y={my} textAnchor={anchor} dominantBaseline="central" fontSize={11} fill="#f2e9d8">
        {p.name}
      </text>
      <text x={tx} y={my + 13} textAnchor={anchor} dominantBaseline="central" fontSize={10} fill="#a3907a">
        {pct}%
      </text>
    </g>
  )
}

/** Pizza (genero) ou rosca (idade), conforme `inner` (px ou "%"). */
function Donut({ data, inner = 0 }: { data: PerfilDatum[]; inner?: number | string }) {
  if (data.length === 0) return <EmptyState />
  const total = data.reduce((s, d) => s + d.total, 0)
  return (
    <ResponsiveContainer width="100%" height="100%">
      <PieChart>
        <Tooltip contentStyle={tooltipStyle} formatter={makeTooltipFormatter(total)} />
        <Pie
          data={data}
          dataKey="total"
          nameKey="categoria"
          cx="50%"
          cy="50%"
          innerRadius={inner}
          outerRadius="62%"
          paddingAngle={0}
          stroke="#191210"
          strokeWidth={1}
          isAnimationActive={false}
          label={renderLeaderLabel}
          labelLine={false}
        >
          {data.map((d, i) => (
            <Cell key={d.categoria} fill={PALETTE[i % PALETTE.length]} />
          ))}
        </Pie>
      </PieChart>
    </ResponsiveContainer>
  )
}

interface PesquisaChartsProps {
  perfil: PesquisaPerfil
  /** Nº de respostas de pesquisa e de leads (para o resumo ao lado do título). */
  respostas: number
  leads: number
}

/**
 * Bloco "Respostas dos compradores" (roadmap item 3): 4 gráficos em grid 2×2.
 * Renda e profissão em barras; idade em rosca; gênero em pizza.
 * Ao lado do título: nº de respostas e % sobre os leads (pesquisa ÷ leads).
 */
export function PesquisaCharts({ perfil, respostas, leads }: PesquisaChartsProps) {
  // % de quem virou lead e respondeu a pesquisa. Cor na escala 0–100 (igual aos KPIs).
  const pct = leads > 0 ? (respostas / leads) * 100 : 0
  const cor = metaColor(pct, 'normal')
  const bom = metaScore(pct, 'normal') >= 0.5

  return (
    <Panel className="p-5">
      {/* Resumo colado à direita do subtítulo (não na ponta do painel). */}
      <div className="mb-4 flex flex-wrap items-end gap-x-3 gap-y-1">
        <SectionTitle overline="Pesquisa" title="Respostas dos compradores" />
        <div className="flex items-baseline gap-2">
          <span className="text-xl font-bold text-cream">{formatInt(respostas)}</span>
          <span className="inline-flex items-center gap-1 text-sm font-bold" style={{ color: cor }}>
            ({formatPct(pct)}
            <TrendArrow up={bom} color={cor} />)
          </span>
        </div>
      </div>
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <ChartFrame title="Renda">
          <HBar data={perfil.renda} />
        </ChartFrame>
        <ChartFrame title="Idade">
          <Donut data={perfil.idade} inner="38%" />
        </ChartFrame>
        <ChartFrame title="Profissão">
          <HBar data={perfil.profissao} />
        </ChartFrame>
        <ChartFrame title="Gênero">
          <Donut data={perfil.genero} />
        </ChartFrame>
      </div>
    </Panel>
  )
}
