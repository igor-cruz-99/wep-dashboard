import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import type { DailyPoint } from '../../types'
import { formatBRL, formatInt } from '../../utils/format'
import { Panel } from '../ui/Panel'

interface ChartCardProps {
  title: string
  data: DailyPoint[]
  /** 'bar' para colunas (Vendas, Investimento) ou 'area' para linha com sombra. */
  kind: 'bar' | 'area'
  /** Cor da série (linha/barras). */
  color: string
  /** Como formatar a média do cabeçalho. */
  headlineFormat?: 'int' | 'brl'
  /** Clique numa coluna/ponto → filtra o painel por aquele dia (YYYY-MM-DD). */
  onSelectDay?: (date: string) => void
}

// Formatação de datas (entrada YYYY-MM-DD).
const dmy = (d: string) => `${d.slice(8, 10)}/${d.slice(5, 7)}/${d.slice(0, 4)}` // dd/mm/aaaa
const dm = (d: string) => `${d.slice(8, 10)}/${d.slice(5, 7)}` // dd/mm
const my = (d: string) => `${d.slice(5, 7)}/${d.slice(2, 4)}` // mm/aa

/** Dias entre a primeira e a última data da série. */
function spanDays(data: { date: string }[]) {
  if (data.length < 2) return 0
  const a = new Date(data[0].date).getTime()
  const b = new Date(data[data.length - 1].date).getTime()
  return Math.abs(b - a) / 86_400_000
}

/** Rótulo do valor em cada marcador/barra (inteiro, fonte pequena). */
const valueLabel = (v: unknown) => Math.round(Number(v)).toString()

const axisTick = { fontSize: 10, fill: '#8d7c68' }
const axisLine = { stroke: '#3a2d21' }

/** Card de gráfico diário: título, média/dia e gráfico (barras ou linha). */
export function ChartCard({
  title,
  data,
  kind,
  color,
  headlineFormat = 'int',
  onSelectDay,
}: ChartCardProps) {
  const avg = data.length
    ? data.reduce((sum, p) => sum + p.value, 0) / data.length
    : 0
  const headline =
    headlineFormat === 'brl' ? formatBRL(Math.round(avg)) : formatInt(Math.round(avg))

  const gradientId = `grad-${title.replace(/\W+/g, '-')}`

  // Período longo (> ~2 meses) → eixo mostra só o mês; curto → dd/mm.
  const longRange = spanDays(data) > 62
  const tickFmt = longRange ? my : dm

  // Clique no gráfico → dispara o dia (activeLabel) pro filtro do painel.
  const handleClick = onSelectDay
    ? (state: { activeLabel?: string | number } | null) => {
        const label = state?.activeLabel
        if (label != null) onSelectDay(String(label))
      }
    : undefined

  const shared = {
    data,
    margin: { top: 14, right: 2, bottom: 2, left: 2 },
    onClick: handleClick,
    style: onSelectDay ? { cursor: 'pointer' as const } : undefined,
  }
  const grid = <CartesianGrid stroke="#a3907a" strokeOpacity={0.15} />
  const xAxis = (
    <XAxis
      dataKey="date"
      tickFormatter={tickFmt}
      tick={axisTick}
      tickLine={false}
      axisLine={axisLine}
      interval="preserveStartEnd"
      minTickGap={40}
    />
  )
  const yAxis = (
    <YAxis tick={axisTick} tickLine={false} axisLine={axisLine} width={34} />
  )
  const tooltip = (
    <Tooltip
      contentStyle={{
        borderRadius: 10,
        border: '1px solid #3a2d21',
        background: '#211a13',
        color: '#f2e9d8',
        fontSize: 12,
      }}
      labelFormatter={(d) => dmy(d as string)}
      formatter={(v) => [v as number, 'Valor']}
      cursor={{ fill: '#f2e9d811' }}
    />
  )
  const labels = (
    <LabelList
      dataKey="value"
      position="top"
      offset={8}
      fontSize={9}
      fill={color}
      formatter={valueLabel}
    />
  )

  return (
    <Panel className="p-4">
      <h3 className="text-[11px] font-semibold uppercase tracking-[0.15em] text-muted">
        {title}
      </h3>
      <p className="mb-2 mt-1">
        <span className="text-2xl font-bold text-cream">{headline}</span>
        <span className="ml-1.5 text-xs text-muted">média/dia</span>
      </p>
      <div className="h-56">
        <ResponsiveContainer width="100%" height="100%">
          {kind === 'bar' ? (
            <BarChart {...shared}>
              {grid}
              {xAxis}
              {yAxis}
              {tooltip}
              <Bar
                dataKey="value"
                fill={color}
                fillOpacity={0.85}
                radius={[3, 3, 0, 0]}
                isAnimationActive={false}
              >
                {labels}
              </Bar>
            </BarChart>
          ) : (
            <AreaChart {...shared}>
              <defs>
                <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={color} stopOpacity={0.32} />
                  <stop offset="100%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              {grid}
              {xAxis}
              {yAxis}
              {tooltip}
              <Area
                type="monotone"
                dataKey="value"
                stroke={color}
                strokeWidth={3}
                fill={`url(#${gradientId})`}
                dot={{ r: 2.5, fill: color, strokeWidth: 0 }}
                activeDot={{ r: 4.5 }}
                isAnimationActive={false}
              >
                {labels}
              </Area>
            </AreaChart>
          )}
        </ResponsiveContainer>
      </div>
    </Panel>
  )
}
