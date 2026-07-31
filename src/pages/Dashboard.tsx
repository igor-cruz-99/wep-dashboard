import { useEffect, useState } from 'react'
import { Header, type Preset } from '../components/layout/Header'
import { Sidebar, type View } from '../components/layout/Sidebar'
import { KpiCard } from '../components/kpi/KpiCard'
import { ChartCard } from '../components/charts/ChartCard'
import { Funnel } from '../components/funnel/Funnel'
import { TrafficTable } from '../components/tables/TrafficTable'
import { PagesTable } from '../components/tables/PagesTable'
import { OrigemLeadsTable } from '../components/tables/OrigemLeadsTable'
import { CplOrigemCard } from '../components/kpi/CplOrigemCard'
import { TrafegoOrganicoPie } from '../components/charts/TrafegoOrganicoPie'
import { PesquisaCharts } from '../components/pesquisa/PesquisaCharts'
import { SealCards } from '../components/seal/SealCards'
import { SealDetailTable } from '../components/seal/SealDetailTable'
import { Panel, SectionTitle } from '../components/ui/Panel'
import { fetchTags } from '../lib/queries'
import type { TagWindow } from '../lib/queries'
import { useDashboardData } from '../hooks/useDashboardData'
import type { Filters, Kpi, PageRow, SealResumo } from '../types'

// Cores das séries. Barras em caramelo; linhas dos combos em cores distintas
// para dar contraste (e casar com as bolinhas ao lado do título).
const SERIES = {
  vendas: '#c9945f', // barras
  cac: '#f5efe0', // linha (creme) do combo Vendas|CAC
  leads: '#c9945f', // barras
  conversaoLeads: '#8fbf7f', // linha (verde) do combo Leads|Conversão
  investimento: '#c9945f',
  conversao: '#c9945f',
}

/**
 * Cards do topo por etapa.
 *  - Meteórico: os 7 atuais (Investimento, Leads, CPL, Vendas, CAC, Grupo, Qualif.).
 *  - Padrão: Investimento, Vendas, CAC, Entrada Grupo (grupo padrão ainda não
 *    criado → "—"), Qualificação, Conversão Página (vendas ÷ page views das
 *    páginas de venda — calculado no front, sem tocar no banco).
 */
function kpisForView(view: View, kpis: Kpi[], pages: PageRow[], seal: SealResumo, entradasGrupo: number): Kpi[] {
  const by = (id: string) => kpis.find((k) => k.id === id)
  if (view === 'seal') {
    // Cards do SEAL: Vendas Ingresso, Conversão SEAL (vendas SEAL ÷ ingressos),
    // Investimento, CAC SEAL (investimento ÷ vendas SEAL).
    const vendasIngresso = Number(by('vendas')?.value ?? 0)
    const investimento = Number(by('investimento')?.value ?? 0)
    const vendasSeal = seal.quitou.alunos + seal.reserva.alunos
    return [
      { id: 'vendasIngresso', label: 'Vendas Ingresso', value: vendasIngresso, format: 'int', direction: 'normal' },
      {
        id: 'conversaoSeal',
        label: 'Conversão SEAL',
        value: vendasIngresso > 0 ? (vendasSeal / vendasIngresso) * 100 : 0,
        format: 'pct',
        direction: 'normal',
      },
      { id: 'investimentoSeal', label: 'Investimento', value: investimento, format: 'brl', direction: 'inverse' },
      {
        id: 'cacSeal',
        label: 'CAC SEAL',
        value: vendasSeal > 0 ? investimento / vendasSeal : 0,
        format: 'brl',
        direction: 'inverse',
        na: vendasSeal === 0,
        naNote: 'sem vendas SEAL',
      },
    ]
  }
  if (view === 'padrao') {
    const vend = pages.filter((p) => /vend/i.test(p.pagina))
    const pv = vend.reduce((s, p) => s + p.pageView, 0)
    const vd = vend.reduce((s, p) => s + p.vendas, 0)
    const conversaoPagina: Kpi = {
      id: 'conversaoPagina',
      label: 'Conversão Página',
      value: pv > 0 ? (vd / pv) * 100 : 0,
      format: 'pct',
      direction: 'normal',
    }
    // Entrada Grupo do Padrão = entradas no grupo padrão ÷ vendas (ingresso).
    const vendasIng = Number(by('vendas')?.value ?? 0)
    const grupoPadrao: Kpi = {
      id: 'grupo',
      label: 'Entrada Grupo',
      value: vendasIng > 0 ? (entradasGrupo / vendasIng) * 100 : 0,
      format: 'pct',
      direction: 'normal',
      na: vendasIng === 0,
      naNote: 'sem vendas no período',
    }
    return [by('investimento'), by('vendas'), by('cac'), grupoPadrao, by('qualificacao'), conversaoPagina].filter(
      Boolean,
    ) as Kpi[]
  }
  // Meteórico (e SEAL por enquanto): conjunto atual completo.
  return kpis
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

// Config de cada etapa (visão da sidebar): título, se mostra o recorte de
// origem e a janela de datas padrão. É a DATA que separa Meteórico de Padrão.
// Tags que aparecem como sub-itens na sidebar. Por ora só o lançamento ativo.
// ⚠️ AO INSERIR novos lançamentos, mantenha esta lista em ORDEM CRONOLÓGICA
//    (ex.: ['WEPAGO26', 'WEPOUT26', 'WEPDEZ26', ...]) — é a ordem em que aparecem.
const SIDEBAR_TAGS = ['WEPAGO26']

// Janela de datas por lançamento para o SEAL. Como vendas_pagarme não tem tag,
// o "filtro de tag" do SEAL é um ATALHO DE PERÍODO: cada lançamento aponta pra
// uma janela que vai até DEPOIS do evento (onde o SEAL é vendido).
// ⚠️ Adicionar novos lançamentos aqui (mesma ordem cronológica da SIDEBAR_TAGS).
const SEAL_TAG_WINDOWS: Record<string, { from: string; to: string }> = {
  WEPAGO26: { from: '2026-07-23', to: '2026-08-31' },
}

const VIEWS: Record<View, { overline: string; showOrigem: boolean; from: string; to: string }> = {
  meteorico: { overline: 'Dashboard Meteórico', showOrigem: true, from: '2026-07-23', to: '2026-07-30' },
  padrao: { overline: 'Dashboard Padrão', showOrigem: false, from: '2026-07-31', to: '2026-08-21' },
  seal: { overline: 'Dashboard SEAL', showOrigem: false, from: '2026-07-23', to: '2026-08-31' },
}

export function Dashboard({ userEmail, onLogout }: DashboardProps) {
  const [tags, setTags] = useState<TagWindow[]>([])
  const [view, setView] = useState<View>('meteorico')
  const [collapsed, setCollapsed] = useState(false)
  const [filters, setFilters] = useState<Filters>({
    tag: 'Todas',
    from: VIEWS.meteorico.from,
    to: VIEWS.meteorico.to,
    origem: 'todas',
    grupo: 'pre_venda',
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
        if (view === 'seal') {
          // No SEAL a tag é um atalho de período (lançamento), não a janela de captação.
          const w = SEAL_TAG_WINDOWS[p.tag ?? '']
          if (w) {
            next.from = w.from
            next.to = w.to
          }
        } else {
          const w = windowForTag(p.tag, tags)
          if (w.from) next.from = w.from
          if (w.to) next.to = w.to
        }
      }
      return next
    })
  }

  /** Troca de etapa pela sidebar: ajusta título, origem e a janela de datas. */
  // Grupo de WhatsApp por etapa (Padrão usa o grupo padrão; resto o pré-venda).
  const grupoForView = (v: View): Filters['grupo'] => (v === 'padrao' ? 'padrao' : 'pre_venda')

  const selectView = (v: View) => {
    exitPreset()
    setView(v)
    const grupo = grupoForView(v)
    if (v === 'seal') {
      // SEAL: a tag é atalho de período (lançamento). Entra no lançamento ativo.
      const tag = SIDEBAR_TAGS[0]
      const w = SEAL_TAG_WINDOWS[tag] ?? { from: VIEWS.seal.from, to: VIEWS.seal.to }
      setFilters((f) => ({ ...f, tag, from: w.from, to: w.to, origem: 'todas', grupo }))
      return
    }
    const cfg = VIEWS[v]
    setFilters((f) => ({
      ...f,
      tag: 'Todas',
      from: cfg.from,
      to: cfg.to,
      origem: cfg.showOrigem ? f.origem : 'todas',
      grupo,
    }))
  }
  /** Clique numa tag (sub-item da sidebar): entra na etapa e filtra a tag. */
  const selectTag = (v: View, tag: string) => {
    exitPreset()
    setView(v)
    const cfg = VIEWS[v]
    setFilters((f) => ({
      ...f,
      tag,
      from: cfg.from,
      to: cfg.to,
      origem: cfg.showOrigem ? f.origem : 'todas',
      grupo: grupoForView(v),
    }))
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

  // Cards do topo variam por etapa (Meteórico 7, Padrão 6, SEAL 4).
  const cards = data ? kpisForView(view, data.kpis, data.pages, data.seal, data.entradasGrupo) : []
  const kpiCols =
    cards.length >= 7 ? 'lg:grid-cols-7' : cards.length === 4 ? 'lg:grid-cols-4' : 'lg:grid-cols-6'

  // Funil por etapa:
  //  - Meteórico: tira Checkouts (Leads→Vendas).
  //  - Padrão: tira Leads (Page Views→Checkouts→Vendas) e o Page Views passa a ser
  //    só das páginas de VENDA (vend) — calculado no front sobre data.pages.
  const vendPageViews = data ? data.pages.filter((p) => /vend/i.test(p.pagina)).reduce((a, p) => a + p.pageView, 0) : 0
  const funnelStages = !data
    ? []
    : view === 'padrao'
      ? data.funnel
          .filter((s) => s.label !== 'Leads')
          .map((s) => (s.label === 'Page Views' ? { ...s, value: vendPageViews } : s))
      : view === 'meteorico'
        ? data.funnel.filter((s) => s.label !== 'Checkouts')
        : data.funnel
  const cacValue = data?.kpis.find((k) => k.id === 'cac')?.value

  // Carrega as tags para o seletor. O período inicial fica no PERIODO_PADRAO
  // (evento atual) e NÃO é sobrescrito pela janela da tag ao abrir — só muda
  // quando o usuário escolhe uma tag específica no Header (ver handleChange).
  useEffect(() => {
    fetchTags()
      .then((ts) => setTags(ts))
      .catch(() => setTags([]))
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
    <div className="flex min-h-screen">
      <Sidebar
        view={view}
        activeTag={filters.tag && filters.tag !== 'Todas' ? filters.tag : null}
        tags={SIDEBAR_TAGS.filter((t) => tags.some((x) => x.tag === t))}
        collapsed={collapsed}
        onToggle={() => setCollapsed((c) => !c)}
        onSelectView={selectView}
        onSelectTag={selectTag}
      />
      <div className="min-w-0 flex-1">
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
        tags={view === 'seal' ? SIDEBAR_TAGS : tagNames}
        onChange={handleChange}
        onClearFilters={view === 'seal' ? undefined : () => handleChange({ tag: 'Todas', origem: 'todas' })}
        activePreset={activePreset}
        onPreset={applyPreset}
        userEmail={userEmail}
        onLogout={onLogout}
        overline={VIEWS[view].overline}
        showTagFilter={view === 'seal'}
        showOrigem={VIEWS[view].showOrigem}
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
          {/* KPIs (variam por etapa) */}
          <div className={`mt-6 grid grid-cols-2 gap-4 md:grid-cols-4 ${kpiCols}`}>
            {cards.map((k) => (
              <KpiCard key={k.id} kpi={k} />
            ))}
          </div>

          {/* Gráficos + funil (Meteórico/Padrão; SEAL não tem) */}
          {view !== 'seal' && (
          <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-[1fr_1.15fr_1fr]">
            {/* Coluna esquerda: sup = Leads|Conversão (Met) ou Vendas|CAC (Pad); inf = Entrada grupo/dia */}
            <div className="flex flex-col gap-4">
              {view === 'padrao' ? (
                <ChartCard
                  title="Vendas por dia | CAC"
                  data={data.series.vendasPorDia}
                  kind="bar"
                  color={SERIES.vendas}
                  seriesLabel="Vendas"
                  line={{ data: data.series.cacPorDia, color: SERIES.cac, label: 'CAC', format: 'brl' }}
                  onSelectDay={selectDay}
                />
              ) : (
                <ChartCard
                  title="Leads por dia | Conversão"
                  data={data.series.leadsPorDia}
                  kind="bar"
                  color={SERIES.leads}
                  seriesLabel="Leads"
                  line={{ data: data.series.conversaoLeadsPorDia, color: SERIES.conversaoLeads, label: 'Conversão', format: 'pct' }}
                  onSelectDay={selectDay}
                />
              )}
              <ChartCard
                title="Entrada no grupo por dia"
                data={data.grupoPorDia}
                kind="bar"
                color={SERIES.leads}
                seriesLabel="Entradas"
                onSelectDay={selectDay}
              />
            </div>

            {/* Funil (etapas e métricas mudam por etapa) */}
            <Panel className="p-5">
              <SectionTitle title="Funil de conversão" titleClassName="text-muted uppercase font-semibold" className="mb-5 text-center" />
              <Funnel stages={funnelStages} cac={cacValue} variant={view} />
            </Panel>

            {/* Coluna direita: sup = Investimento/dia; inf = Respostas pesquisa/dia (Met) ou Conversão Checkout/dia (Pad) */}
            <div className="flex flex-col gap-4">
              <ChartCard
                title="Investimento por dia"
                data={data.series.investimentoPorDia}
                kind="bar"
                color={SERIES.investimento}
                headlineFormat="brl"
                onSelectDay={selectDay}
              />
              {view === 'padrao' ? (
                <ChartCard
                  title="Conversão Checkout por dia"
                  data={data.series.conversaoPorDia}
                  kind="area"
                  color={SERIES.conversao}
                  onSelectDay={selectDay}
                />
              ) : (
                <ChartCard
                  title="Respostas pesquisa por dia"
                  data={data.series.pesquisaPorDia}
                  kind="bar"
                  color={SERIES.leads}
                  seriesLabel="Respostas"
                  onSelectDay={selectDay}
                />
              )}
            </div>
          </div>
          )}

          {/* Origem dos Leads | CPL | Tráfego x Orgânico — só Meteórico */}
          {view === 'meteorico' && (
            <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-3">
              <OrigemLeadsTable rows={data.origemLeads} />
              <CplOrigemCard data={data.cplOrigem} />
              <TrafegoOrganicoPie data={data.trafegoOrganico} />
            </div>
          )}

          {/* Análise + Pesquisa (Meteórico/Padrão) — SEAL tem seu próprio corpo */}
          {view !== 'seal' && (
            <div className="mt-6 flex flex-col gap-6">
              {/* Tráfego por campanha: nas duas etapas */}
              <TrafficTable rows={data.traffic} />

              {/* Página de captação (Meteórico) / de vendas (Padrão) */}
              {view === 'meteorico' ? (
                <PagesTable
                  rows={data.pages.filter((p) => /cap|forms/i.test(p.pagina))}
                  title="Desempenho página de captação"
                  colKeys={['pagina', 'pageView', 'leads', 'pesquisa']}
                />
              ) : (
                <PagesTable
                  rows={data.pages.filter((p) => /vend/i.test(p.pagina))}
                  title="Desempenho página de vendas"
                  colKeys={['pagina', 'pageView', 'checkout', 'vendas', 'checkoutVenda', 'visitaCheckout', 'visitaVenda']}
                />
              )}

              {/* Pesquisa: mesma pesquisa, título muda por etapa */}
              <PesquisaCharts
                perfil={data.perfil}
                respostas={data.pesquisaResumo.respostas}
                leads={data.pesquisaResumo.leads}
                title={view === 'padrao' ? 'Respostas dos compradores' : 'Respostas da pesquisa'}
              />
            </div>
          )}

          {/* SEAL — só na aba SEAL. Situação de pagamento + compradores; a tabela
              de indicadores nova entra aqui quando você mandar os campos. */}
          {view === 'seal' && (
            <div className="mt-6 flex flex-col gap-6">
              <div className="flex flex-col gap-4">
                <SectionTitle overline="SEAL" title="Situação de pagamento" />
                <SealCards
                  seal={data.seal}
                  investimento={data.funnel.find((s) => s.label === 'Investimento')?.value ?? 0}
                />
                <SealDetailTable rows={data.sealCompradores} tag={filters.tag} />
              </div>
            </div>
          )}
        </>
      )}
        </div>
      </div>
    </div>
  )
}
