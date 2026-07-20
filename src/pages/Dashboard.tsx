import { useEffect, useState } from 'react'
import { Header, type Preset } from '../components/layout/Header'
import { KpiCard } from '../components/kpi/KpiCard'
import { ChartCard } from '../components/charts/ChartCard'
import { Funnel } from '../components/funnel/Funnel'
import { TrafficTable } from '../components/tables/TrafficTable'
import { PagesTable } from '../components/tables/PagesTable'
import { Panel, SectionTitle } from '../components/ui/Panel'
import { fetchTags } from '../lib/queries'
import type { TagWindow } from '../lib/queries'
import { useDashboardData } from '../hooks/useDashboardData'
import type { Filters } from '../types'

// Cores das séries — marrom claro / caramelo
const SERIES = {
  vendas: '#c9945f',
  cac: '#c9945f',
  investimento: '#c9945f',
  conversao: '#c9945f',
}

/**
 * Janela de datas de uma tag. 'Todas' (ou null) = união de todas as janelas
 * (menor início → maior fim). Retorna null quando não há tags carregadas.
 */
function windowForTag(tag: string | null, list: TagWindow[]) {
  if (tag && tag !== 'Todas') {
    const t = list.find((x) => x.tag === tag)
    return { from: t?.from ?? null, to: t?.to ?? null }
  }
  const froms = list.map((t) => t.from).filter((v): v is string => Boolean(v)).sort()
  const tos = list.map((t) => t.to).filter((v): v is string => Boolean(v)).sort()
  return {
    from: froms[0] ?? null,
    to: tos[tos.length - 1] ?? null,
  }
}

interface DashboardProps {
  userEmail?: string
  onLogout?: () => void
}

export function Dashboard({ userEmail, onLogout }: DashboardProps) {
  const [tags, setTags] = useState<TagWindow[]>([])
  const [filters, setFilters] = useState<Filters>({
    tag: 'Todas',
    // Placeholder amplo até as tags carregarem e definirem a janela.
    from: '2025-01-01',
    to: '2026-12-31',
    campanha: null,
    conjunto: null,
    anuncio: null,
  })

  // Atalho de período ativo (30D/7D/1D) e o período anterior pra reverter.
  const [activePreset, setActivePreset] = useState<Preset | null>(null)
  const [presetPrev, setPresetPrev] = useState<{ from: string; to: string } | null>(null)
  const exitPreset = () => {
    setActivePreset(null)
    setPresetPrev(null)
  }

  const setF = (p: Partial<Filters>) => setFilters((f) => ({ ...f, ...p }))

  /** Mudanças vindas do Header. Se a TAG mudar, o período vira a janela dela. */
  const handleChange = (p: Partial<Filters>) => {
    exitPreset() // qualquer mudança manual de tag/data sai do modo atalho
    setFilters((f) => {
      const next = { ...f, ...p }
      if (p.tag !== undefined) {
        const w = windowForTag(p.tag, tags)
        if (w.from) next.from = w.from
        if (w.to) next.to = w.to
      }
      return next
    })
  }

  // Data local no formato YYYY-MM-DD (sem shift de fuso).
  const toISO = (d: Date) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

  /** Aplica/alterna um atalho: 30D/7D/1D. Reclique volta ao período anterior. */
  const applyPreset = (preset: Preset) => {
    if (activePreset === preset) {
      if (presetPrev) setF({ from: presetPrev.from, to: presetPrev.to })
      exitPreset()
      return
    }
    const days = preset === '30D' ? 30 : preset === '7D' ? 7 : 1
    const from = new Date()
    from.setDate(from.getDate() - (days - 1))
    if (!activePreset) setPresetPrev({ from: filters.from, to: filters.to })
    setActivePreset(preset)
    setF({ from: toISO(from), to: toISO(new Date()) })
  }

  const { data, loading, error } = useDashboardData(filters)

  // Carrega tags + define o período inicial pela tag selecionada.
  useEffect(() => {
    fetchTags()
      .then((ts) => {
        setTags(ts)
        const w = windowForTag(filters.tag, ts)
        if (w.from && w.to) setFilters((f) => ({ ...f, from: w.from!, to: w.to! }))
      })
      .catch(() => setTags([]))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const tagNames = ['Todas', ...tags.map((t) => t.tag)]

  // Clique numa coluna/ponto do gráfico → filtra o painel por aquele dia.
  const selectDay = (date: string) => {
    exitPreset()
    setF({ from: date, to: date })
  }
  const isSingleDay = filters.from === filters.to
  const clearDay = () => {
    exitPreset()
    const w = windowForTag(filters.tag, tags)
    setF({ from: w.from ?? filters.from, to: w.to ?? filters.to })
  }

  return (
    <div className="mx-auto max-w-[1600px] px-6 py-6">
      {/* Status da fonte de dados */}
      <div className="mb-4 flex items-center gap-3 text-xs text-muted">
        <span
          className={`inline-block h-2 w-2 rounded-full ${
            error ? 'bg-[#e07b4f]' : loading ? 'bg-gold' : 'bg-[#8fbf7f]'
          }`}
        />
        {error
          ? `Erro ao carregar: ${error}`
          : loading
            ? 'Carregando dados do Supabase…'
            : 'Dados ao vivo do Supabase'}

        {isSingleDay && (
          <button
            onClick={clearDay}
            className="ml-2 flex items-center gap-1 rounded-full border border-line bg-card-2 px-3 py-0.5 text-[11px] text-muted hover:text-cream"
          >
            <span className="text-cream">Dia: {filters.from}</span>
            <span aria-hidden>✕</span>
          </button>
        )}
      </div>

      <Header
        filters={filters}
        tags={tagNames}
        onChange={handleChange}
        onClearFilters={() => handleChange({ tag: 'Todas' })}
        activePreset={activePreset}
        onPreset={applyPreset}
        userEmail={userEmail}
        onLogout={onLogout}
      />

      {/* Estados sem dados: erro ou carregando (sem dados fictícios) */}
      {!data ? (
        <div className="mt-10 flex items-center justify-center">
          {error ? (
            <div className="max-w-lg rounded-xl border border-[#e07b4f]/40 bg-card px-6 py-5 text-center text-sm text-muted">
              <p className="mb-1 font-semibold text-cream">Não foi possível carregar os dados</p>
              <p>{error}</p>
            </div>
          ) : (
            <div className="flex items-center gap-3 py-16 text-sm text-muted">
              <span className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-line border-t-gold" />
              Carregando dados…
            </div>
          )}
        </div>
      ) : (
        <>
          {/* KPIs */}
          <div className="mt-6 grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-5">
            {data.kpis.map((k) => (
              <KpiCard key={k.id} kpi={k} />
            ))}
          </div>

          {/* Gráficos + funil */}
          <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-[1fr_1.15fr_1fr]">
            <div className="flex flex-col gap-4">
              <ChartCard
                title="Vendas por dia"
                data={data.series.vendasPorDia}
                kind="bar"
                color={SERIES.vendas}
                onSelectDay={selectDay}
              />
              <ChartCard
                title="CAC por dia"
                data={data.series.cacPorDia}
                kind="area"
                color={SERIES.cac}
                headlineFormat="brl"
                onSelectDay={selectDay}
              />
            </div>

            <Panel className="p-5">
              <SectionTitle title="Funil de conversão" titleClassName="text-muted uppercase font-semibold" className="mb-5 text-center" />
              <Funnel stages={data.funnel} />
            </Panel>

            <div className="flex flex-col gap-4">
              <ChartCard
                title="Investimento por dia"
                data={data.series.investimentoPorDia}
                kind="bar"
                color={SERIES.investimento}
                headlineFormat="brl"
                onSelectDay={selectDay}
              />
              <ChartCard
                title="Conversão por dia"
                data={data.series.conversaoPorDia}
                kind="area"
                color={SERIES.conversao}
                onSelectDay={selectDay}
              />
            </div>
          </div>

          {/* Tabelas */}
          <div className="mt-6 flex flex-col gap-6">
            <TrafficTable rows={data.traffic} />
            <PagesTable rows={data.pages} />
          </div>
        </>
      )}
    </div>
  )
}
