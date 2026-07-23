import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  ComposedChart,
  LabelList,
  Line,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import type { DailyPoint } from '../../types'
import { formatBRL, formatInt } from '../../utils/format'
import { Panel } from '../ui/Panel'

type ValueFormat = 'int' | 'brl' | 'pct'

/** Série de linha secundária, sobreposta às barras (eixo Y à direita). */
interface LineSeries {
  data: DailyPoint[]
  color: string
  label: string
  format?: ValueFormat
}

interface ChartCardProps {
  title: string
  data: DailyPoint[]
  /** 'bar' para colunas (Vendas, Investimento) ou 'area' para linha com sombra. */
  kind: 'bar' | 'area'
  /** Cor da série (linha/barras). */
  color: string
  /** Rótulo da série primária (usado na legenda/tooltip quando há combo). */
  seriesLabel?: string
  /** Como formatar a média do cabeçalho. */
  headlineFormat?: 'int' | 'brl'
  /** Linha secundária → vira gráfico combo (barras + linha, eixo duplo). */
  line?: LineSeries
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

const fmtBy = (f: ValueFormat | undefined, v: number) =>
  f === 'brl' ? formatBRL(v) : f === 'pct' ? `${Math.round(v)}%` : formatInt(v)

/** Rótulo do valor em cada marcador/barra (inteiro, fonte pequena). */
const valueLabel = (v: unknown) => Math.round(Number(v)).toString()

const axisTick = { fontSize: 10, fill: '#8d7c68' }
const axisLine = { stroke: '#3a2d21' }

/**
 * Card de gráfico diário. Simples (barras ou área) ou COMBO: quando recebe
 * `line`, vira barras (série primária, eixo esquerdo) + linha (secundária,
 * eixo direito), com bolinhas coloridas ao lado do título identificando cada série.
 */
export function ChartCard({
  title,
  data,
  kind,
  color,
  seriesLabel = 'Valor',
  headlineFormat = 'int',
  line,
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

  // Combo: junta as duas séries por data (mesmo eixo temporal da fn_serie_diaria).
  const comboData = line
    ? (() => {
        const map = new Map(data.map((p) => [p.date, { date: p.date, value: p.value, line: 0 }]))
        for (const p of line.data) {
          const e = map.get(p.date) ?? { date: p.date, value: 0, line: 0 }
          e.line = p.value
          map.set(p.date, e)
        }
        return [...map.values()].sort((a, b) => (a.date < b.date ? -1 : 1))
      })()
    : []

  const shared = {
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
  const tooltipBase = {
    contentStyle: {
      borderRadius: 10,
      border: '1px solid #3a2d21',
      background: '#211a13',
      color: '#f2e9d8',
      fontSize: 12,
    },
    labelFormatter: (d: unknown) => dmy(d as string),
    cursor: { fill: '#f2e9d811' },
  }

  // Combo: cada segmento do título ("A | B") ganha uma bolinha à esquerda, na
  // cor da sua série — A = barras (color), B = linha (line.color).
  const segColors = [color, line?.color ?? color]

  return (
    <Panel className="flex h-full flex-1 flex-col p-4">
      <h3 className="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[11px] font-semibold uppercase tracking-[0.15em] text-muted">
        {line
          ? title.split(' | ').map((seg, i) => (
              <span key={i} className="flex items-center gap-1.5">
                {i > 0 && <span className="opacity-40">|</span>}
                <span
                  className="inline-block h-2 w-2 shrink-0 rounded-full"
                  style={{ background: segColors[i] ?? color }}
                />
                {seg}
              </span>
            ))
          : title}
      </h3>
      <p className="mb-2 mt-1">
        <span className="text-2xl font-bold text-cream">{headline}</span>
        <span className="ml-1.5 text-xs text-muted">média/dia</span>
      </p>
      {/* flex-1: o gráfico cresce para preencher a altura da coluna (alinha com o funil). */}
      <div className="min-h-[224px] flex-1">
        <ResponsiveContainer width="100%" height="100%">
          {line ? (
            <ComposedChart data={comboData} {...shared}>
              {grid}
              {xAxis}
              <YAxis yAxisId="left" tick={axisTick} tickLine={false} axisLine={axisLine} width={30} />
              <YAxis
                yAxisId="right"
                orientation="right"
                tick={axisTick}
                tickLine={false}
                axisLine={axisLine}
                width={34}
              />
              <Tooltip
                {...tooltipBase}
                formatter={(v, name) =>
                  name === line.label
                    ? [fmtBy(line.format, Number(v)), line.label]
                    : [fmtBy(headlineFormat, Number(v)), seriesLabel]
                }
              />
              <Bar
                yAxisId="left"
                name={seriesLabel}
                dataKey="value"
                fill={color}
                fillOpacity={0.85}
                radius={[3, 3, 0, 0]}
                isAnimationActive={false}
              />
              <Line
                yAxisId="right"
                name={line.label}
                type="monotone"
                dataKey="line"
                stroke={line.color}
                strokeWidth={2.5}
                dot={{ r: 2, fill: line.color, strokeWidth: 0 }}
                activeDot={{ r: 4 }}
                isAnimationActive={false}
              />
            </ComposedChart>
          ) : kind === 'bar' ? (
            <BarChart data={data} {...shared}>
              {grid}
              {xAxis}
              <YAxis tick={axisTick} tickLine={false} axisLine={axisLine} width={34} />
              <Tooltip {...tooltipBase} formatter={(v) => [v as number, seriesLabel]} />
              <Bar
                dataKey="value"
                fill={color}
                fillOpacity={0.85}
                radius={[3, 3, 0, 0]}
                isAnimationActive={false}
              >
                <LabelList dataKey="value" position="top" offset={8} fontSize={9} fill={color} formatter={valueLabel} />
              </Bar>
            </BarChart>
          ) : (
            <AreaChart data={data} {...shared}>
              <defs>
                <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={color} stopOpacity={0.32} />
                  <stop offset="100%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              {grid}
              {xAxis}
              <YAxis tick={axisTick} tickLine={false} axisLine={axisLine} width={34} />
              <Tooltip {...tooltipBase} formatter={(v) => [v as number, seriesLabel]} />
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
                <LabelList dataKey="value" position="top" offset={8} fontSize={9} fill={color} formatter={valueLabel} />
              </Area>
            </AreaChart>
          )}
        </ResponsiveContainer>
      </div>
    </Panel>
  )
}
