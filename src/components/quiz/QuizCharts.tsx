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
import type { PerfilDatum, QuizPerfil } from '../../types'
import { formatInt } from '../../utils/format'
import { Panel, SectionTitle } from '../ui/Panel'

// Mesma paleta do bloco Pesquisa (ver PesquisaCharts.tsx) — painel duplicado
// de propósito, pra editar um sem afetar o outro.
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

/** Barras horizontais — bom para categorias de rótulo longo (profissão). */
function HBar({ data }: { data: PerfilDatum[] }) {
  if (data.length === 0) return <EmptyState />
  const total = data.reduce((s, d) => s + d.total, 0)
  return (
    <ResponsiveContainer width="100%" height="100%">
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

/** Barras verticais — bom para respostas curtas (Sim/Não). */
function VBar({ data }: { data: PerfilDatum[] }) {
  if (data.length === 0) return <EmptyState />
  const total = data.reduce((s, d) => s + d.total, 0)
  return (
    <ResponsiveContainer width="100%" height="100%">
      <BarChart data={data} margin={{ top: 20, right: 8, bottom: 4, left: 8 }}>
        <XAxis
          type="category"
          dataKey="categoria"
          tick={AXIS_TICK}
          tickLine={false}
          axisLine={{ stroke: '#3a2d21' }}
        />
        <YAxis type="number" tick={AXIS_TICK} tickLine={false} axisLine={{ stroke: '#3a2d21' }} allowDecimals={false} />
        <Tooltip contentStyle={tooltipStyle} cursor={{ fill: '#f2e9d811' }} formatter={makeTooltipFormatter(total)} />
        <Bar dataKey="total" fill={BAR_COLOR} radius={[3, 3, 0, 0]} isAnimationActive={false}>
          <LabelList
            dataKey="total"
            position="top"
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

interface PieLabelProps {
  cx?: number
  cy?: number
  midAngle?: number
  outerRadius?: number
  percent?: number
  name?: string
}

function renderLeaderLabel(p: PieLabelProps) {
  const RAD = Math.PI / 180
  const cx = p.cx ?? 0
  const cy = p.cy ?? 0
  const outerRadius = p.outerRadius ?? 0
  const cos = Math.cos(-(p.midAngle ?? 0) * RAD)
  const sin = Math.sin(-(p.midAngle ?? 0) * RAD)
  const right = cos >= 0
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

/** Rosca — usada em Renda. */
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

interface QuizChartsProps {
  perfil: QuizPerfil
  /** Nº de respostas do quiz no período (ao lado do título). */
  respostas: number
  /** Nº de linhas com status contendo "Comprou" (canto direito do painel). */
  vendas: number
}

/**
 * Bloco "Quiz - InLead": mesma estrutura do bloco Pesquisa, dados de
 * mkt_wep.wep_quiz (campanha ls-WEP-WEPAGO26-QUIZ-captacao-vendas).
 */
export function QuizCharts({ perfil, respostas, vendas }: QuizChartsProps) {
  return (
    <Panel className="p-5">
      <div className="mb-4 flex flex-wrap items-end justify-between gap-x-3 gap-y-1">
        <div className="flex flex-wrap items-end gap-x-3 gap-y-1">
          <SectionTitle overline="Quiz - InLead" title="Respostas" />
          <span className="text-xl font-bold text-cream">{formatInt(respostas)}</span>
        </div>
        <div className="text-sm text-muted">
          Vendas: <span className="text-base font-bold text-cream">{formatInt(vendas)}</span>
        </div>
      </div>
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <ChartFrame title="Profissão">
          <HBar data={perfil.profissao} />
        </ChartFrame>
        <ChartFrame title="Renda">
          <Donut data={perfil.renda} inner="38%" />
        </ChartFrame>
        <ChartFrame title="Alguém da sua rede já te procurou pra pedir conselhos?">
          <VBar data={perfil.alguemNaRede} />
        </ChartFrame>
        <ChartFrame title="Você já deu conselhos financeiros?">
          <VBar data={perfil.jaDeuConselhos} />
        </ChartFrame>
      </div>
    </Panel>
  )
}
