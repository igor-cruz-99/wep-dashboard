import { useEffect, useState } from 'react'
import { Header, type Preset } from '../components/layout/Header'
import { Sidebar, type View } from '../components/layout/Sidebar'
import { KpiCard } from '../components/kpi/KpiCard'
import { ChartCard } from '../components/charts/ChartCard'
import { Funnel } from '../components/funnel/Funnel'
import { TrafficTable } from '../components/tables/TrafficTable'
import { AdThumbnailModal } from '../components/tables/AdThumbnailModal'
import { PagesTable } from '../components/tables/PagesTable'
import { BuyersTable } from '../components/tables/BuyersTable'
import { GaleriaCriativos } from '../components/criativos/GaleriaCriativos'
import { CriativoModal } from '../components/criativos/CriativoModal'
import { OrigemLeadsTable } from '../components/tables/OrigemLeadsTable'
import { CplOrigemCard } from '../components/kpi/CplOrigemCard'
import { TrafegoOrganicoPie } from '../components/charts/TrafegoOrganicoPie'
import { PesquisaCharts } from '../components/pesquisa/PesquisaCharts'
import { QuizCharts } from '../components/quiz/QuizCharts'
import { SealCards } from '../components/seal/SealCards'
import { SealDetailTable } from '../components/seal/SealDetailTable'
import { Panel, SectionTitle } from '../components/ui/Panel'
import { fetchTags, fetchCriativos, fetchCompradores } from '../lib/queries'
import type { TagWindow } from '../lib/queries'
import { useDashboardData } from '../hooks/useDashboardData'
import type { Comprador, CriativoGaleria, Filters, Kpi, PageRow, SealResumo, TrafficRow } from '../types'

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
    // Cards do SEAL, na ordem: Vendas Ingresso, Vendas SEAL, Conversão SEAL,
    // Investimento, Faturamento SEAL, CAC SEAL.
    const vendasIngresso = Number(by('vendas')?.value ?? 0)
    const investimento = Number(by('investimento')?.value ?? 0)
    // Vendas SEAL é o TOTAL: completa + complemento. Quem pagou só uma parte
    // já é venda — só não é venda fechada. A separação entre as duas mora nos
    // cards de situação logo abaixo; aqui em cima o número é o agregado, e é
    // por ele que CAC e conversão dividem.
    const vendasSeal = seal.completa.alunos + seal.complemento.alunos
    const faturamentoSeal = seal.completa.valorTotal + seal.complemento.valorTotal
    return [
      { id: 'vendasIngresso', label: 'Vendas Ingresso', value: vendasIngresso, format: 'int', direction: 'normal' },
      { id: 'vendasSeal', label: 'Vendas SEAL', value: vendasSeal, format: 'int', direction: 'normal' },
      {
        id: 'conversaoSeal',
        label: 'Conversão SEAL',
        value: vendasIngresso > 0 ? (vendasSeal / vendasIngresso) * 100 : 0,
        format: 'pct',
        direction: 'normal',
      },
      { id: 'investimentoSeal', label: 'Investimento', value: investimento, format: 'brl', direction: 'inverse' },
      {
        id: 'faturamentoSeal',
        label: 'Faturamento SEAL',
        value: faturamentoSeal,
        format: 'brl',
        direction: 'normal',
      },
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
    const vend = pages.filter((p) => /vend|-pv-/i.test(p.pagina))
    const pv = vend.reduce((s, p) => s + p.pageView, 0)
    const vd = vend.reduce((s, p) => s + p.vendas, 0)
    const conversaoPagina: Kpi = {
      id: 'conversaoPagina',
      label: 'Conversão Página',
      value: pv > 0 ? (vd / pv) * 100 : 0,
      format: 'pct',
      direction: 'normal',
    }
    // Entrada Grupo do Padrão: o número de pessoas no grupo é o valor principal,
    // e o percentual (entradas ÷ vendas) fica ao lado. É o percentual, não o
    // número, que se compara com a meta_grupo da wep_tags — ela é percentual,
    // como a meta_qualificacao ao lado dela na tabela.
    const vendasIng = Number(by('vendas')?.value ?? 0)
    const grupoPct = vendasIng > 0 ? (entradasGrupo / vendasIng) * 100 : 0
    const grupoPadrao: Kpi = {
      id: 'grupo',
      label: 'Entrada Grupo',
      value: entradasGrupo,
      pctLado: grupoPct,
      meta: by('grupo')?.meta,
      format: 'int',
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

// Lançamentos que aparecem como sub-itens na sidebar.
// ⚠️ ORDEM CRONOLÓGICA — é a ordem em que aparecem, e o ÚLTIMO é tratado como
//    a edição ativa (a que o painel abre e a que o SEAL usa como atalho).
const SIDEBAR_TAGS = ['WEPAGO26', 'WEPSET26']
const TAG_ATIVA = SIDEBAR_TAGS[SIDEBAR_TAGS.length - 1]

/**
 * Janela de datas por (lançamento, etapa).
 *
 * Por que não basta a janela da wep_tags: a tabela guarda a captação inteira
 * do lançamento, e é a DATA que separa Meteórico de Padrão dentro dela. Em
 * WEPAGO26 a captação vai de 01/07 a 30/08, mas o Meteórico é só a semana do
 * evento e o Padrão é o que vem depois — usar a janela da tag jogaria os dois
 * períodos na mesma tela.
 *
 * A etapa AUSENTE aqui não existe naquele lançamento, e a sidebar não oferece
 * o lançamento dentro dela. É assim que WEPSET26 não aparece no Meteórico:
 * esta edição não tem fase meteórica, a operação inteira roda no Padrão.
 *
 * O SEAL é caso à parte: vendas_pagarme não tem coluna de tag, então o
 * "filtro de tag" do SEAL é só um atalho de período.
 *
 * ⚠️ AO ABRIR UM LANÇAMENTO NOVO: acrescente a entrada aqui e o nome na
 *    SIDEBAR_TAGS. Sem a entrada, o lançamento some da sidebar.
 */
const TAG_WINDOWS: Record<string, Partial<Record<View, { from: string; to: string }>>> = {
  WEPAGO26: {
    meteorico: { from: '2026-07-23', to: '2026-07-30' },
    padrao: { from: '2026-07-31', to: '2026-08-21' },
    anuncios: { from: '2026-07-31', to: '2026-08-21' },
    // SEAL vai até depois do evento, que é quando ele é vendido.
    seal: { from: '2026-07-23', to: '2026-08-31' },
  },
  WEPSET26: {
    // Sem Meteórico nesta edição — de propósito, não é esquecimento.
    padrao: { from: '2026-09-10', to: '2026-09-20' },
    anuncios: { from: '2026-09-10', to: '2026-09-20' },
    seal: { from: '2026-09-10', to: '2026-09-20' },
  },
}

/**
 * Edições que não rodam o Quiz InLead. O bloco some da tela em vez de aparecer
 * zerado — um gráfico vazio parece dado faltando, e faz procurar bug onde não
 * há. WEPAGO26 mantém o dele, que é histórico real.
 */
const TAGS_SEM_QUIZ = new Set(['WEPSET26'])

/** Lançamentos que têm a etapa `v` — o que a sidebar oferece dentro dela. */
const tagsForView = (v: View) => SIDEBAR_TAGS.filter((t) => TAG_WINDOWS[t]?.[v])

/**
 * Janela de (tag, etapa), caindo para a etapa na edição ativa e, no limite,
 * para o Padrão da ativa. O fallback existe para o painel nunca abrir sem
 * período — se cair nele, falta uma entrada no TAG_WINDOWS.
 */
const janela = (tag: string | null, v: View): { from: string; to: string } =>
  TAG_WINDOWS[tag ?? '']?.[v] ?? TAG_WINDOWS[TAG_ATIVA]?.[v] ?? TAG_WINDOWS[TAG_ATIVA].padrao!

// Config de cada etapa: título e se mostra o recorte de origem. As datas vêm
// do TAG_WINDOWS, porque dependem do lançamento.
const VIEWS: Record<View, { overline: string; showOrigem: boolean }> = {
  meteorico: { overline: 'Dashboard Meteórico', showOrigem: true },
  padrao: { overline: 'Dashboard Padrão', showOrigem: false },
  anuncios: { overline: 'Anúncios', showOrigem: false },
  seal: { overline: 'Dashboard SEAL', showOrigem: false },
}

export function Dashboard({ userEmail, onLogout }: DashboardProps) {
  const [tags, setTags] = useState<TagWindow[]>([])
  // Abre no Padrão: a edição ativa (WEPSET26) não tem fase meteórica, e é o
  // Padrão que roda a operação inteira dela.
  const [view, setView] = useState<View>('padrao')
  const [collapsed, setCollapsed] = useState(false)
  // Anúncio clicado na tabela de tráfego (abre o popup de preview) — feature
  // pausada e AINDA NÃO COMMITADA (memória: wep-thumbnail-anuncio-opcaoB).
  // Fica só no disco local até retomar; não publicar sem querer.
  const [adPreview, setAdPreview] = useState<TrafficRow | null>(null)
  // Galeria de criativos (aba Anúncios). Carrega sob demanda: só quando a aba
  // está aberta, para não pesar as outras telas com uma consulta que elas não
  // usam.
  const [criativos, setCriativos] = useState<CriativoGaleria[]>([])
  const [criativosLoading, setCriativosLoading] = useState(false)
  const [criativoAberto, setCriativoAberto] = useState<CriativoGaleria | null>(null)
  // Compradores linha a linha (bloco "Vendas / Por compradores", só no Padrão).
  // Mesmo motivo da galeria: consulta que só uma tela usa não deve pesar as
  // outras, então carrega sob demanda em vez de entrar no useDashboardData.
  const [compradores, setCompradores] = useState<Comprador[]>([])
  // Abre na edição ATIVA, não em 'Todas': com p_tag nulo a fn_kpis SOMA as
  // metas de todas as tags da wep_tags, e somar meta de CAC de dois
  // lançamentos não significa nada. Enquanto só WEPAGO26 tinha metas isso
  // passava despercebido; com a segunda edição preenchida, não passa mais.
  const [filters, setFilters] = useState<Filters>({
    tag: TAG_ATIVA,
    from: janela(TAG_ATIVA, 'padrao').from,
    to: janela(TAG_ATIVA, 'padrao').to,
    origem: 'todas',
    grupo: 'padrao',
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
        // Mesma regra da sidebar: a janela é do PAR (lançamento, etapa). Se o
        // par não estiver mapeado — tags que existem na wep_tags mas ainda não
        // abriram, como WEPOUT26 — cai na janela de captação da tabela.
        const mapeada = TAG_WINDOWS[p.tag ?? '']?.[view]
        if (mapeada) {
          next.from = mapeada.from
          next.to = mapeada.to
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
    // Mantém o lançamento em que o usuário está, se ele tiver esta etapa; senão
    // cai na edição MAIS RECENTE que tenha. Ex.: quem está no WEPSET26 e clica
    // em Meteórico vai para o WEPAGO26 — é o único com fase meteórica, e cair
    // na edição ativa deixaria o Meteórico com as datas de setembro, um período
    // em que essa etapa nem existiu.
    const comEtapa = tagsForView(v)
    const tag = TAG_WINDOWS[filters.tag ?? '']?.[v]
      ? (filters.tag as string)
      : (comEtapa[comEtapa.length - 1] ?? TAG_ATIVA)
    const w = janela(tag, v)
    setFilters((f) => ({
      ...f,
      tag,
      from: w.from,
      to: w.to,
      origem: VIEWS[v].showOrigem ? f.origem : 'todas',
      grupo,
    }))
  }
  /** Clique numa tag (sub-item da sidebar): entra na etapa e filtra a tag. */
  const selectTag = (v: View, tag: string) => {
    exitPreset()
    setView(v)
    // A janela é do PAR (lançamento, etapa): trocar de edição tem que trocar o
    // período junto, senão o WEPSET26 abriria com as datas de agosto.
    const w = janela(tag, v)
    setFilters((f) => ({
      ...f,
      tag,
      from: w.from,
      to: w.to,
      origem: VIEWS[v].showOrigem ? f.origem : 'todas',
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
  //  - Padrão: tira Leads (Page Views→Checkouts→Vendas).
  //
  // O Page Views do Padrão (só páginas de venda) é calculado no BANCO, via
  // p_so_vendas na fn_funil (sql/64). Antes era recalculado aqui filtrando
  // data.pages por /vend|-pv-/, o que ignorava as páginas que converteram sem
  // ter esse padrão no slug: as LPs novas (wep-lp02-h1-v1, wep-lp04-h1-v4)
  // sumiam e o funil mostrava 33 onde a tabela mostrava 462. Um cálculo só,
  // na mesma fonte da tabela, evita os dois números divergirem de novo.
  const funnelStages = !data
    ? []
    : view === 'padrao'
      ? data.funnel.filter((s) => s.label !== 'Leads')
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

  // Criativos da aba Anúncios: recarrega quando a aba abre ou o período muda.
  useEffect(() => {
    if (view !== 'anuncios') return
    let cancelado = false
    setCriativosLoading(true)
    fetchCriativos(filters)
      .then((cs) => {
        if (!cancelado) setCriativos(cs)
      })
      .catch(() => {
        if (!cancelado) setCriativos([])
      })
      .finally(() => {
        if (!cancelado) setCriativosLoading(false)
      })
    return () => {
      cancelado = true
    }
  }, [view, filters.from, filters.to])

  // Compradores do Padrão: acompanha os mesmos filtros do topo do painel, para
  // a contagem de linhas bater com a etapa Vendas do funil.
  useEffect(() => {
    if (view !== 'padrao') return
    let cancelado = false
    fetchCompradores(filters)
      .then((cs) => {
        if (!cancelado) setCompradores(cs)
      })
      .catch(() => {
        if (!cancelado) setCompradores([])
      })
    return () => {
      cancelado = true
    }
  }, [view, filters.from, filters.to, filters.tag, filters.origem, filters.grupo])

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
        tags={tagsForView(view).filter((t) => tags.some((x) => x.tag === t))}
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
          {/* Anúncios: só a galeria de criativos. Sem KPIs nem gráficos — a
              tela responde "qual peça performa", e cards/funil dessa mesma
              operação já estão no Padrão. */}
          {view === 'anuncios' && (
            <div className="mt-6">
              {criativosLoading ? (
                <div className="flex items-center justify-center gap-3 py-20 text-sm text-muted">
                  <span className="inline-block h-4 w-4 animate-spin rounded-full border-2 border-line border-t-gold" />
                  Carregando criativos…
                </div>
              ) : (
                <GaleriaCriativos criativos={criativos} onAbrir={setCriativoAberto} />
              )}
            </div>
          )}

          {/* KPIs (variam por etapa) */}
          {view !== 'anuncios' && (
          <div className={`mt-6 grid grid-cols-2 gap-4 md:grid-cols-4 ${kpiCols}`}>
            {cards.map((k) => (
              <KpiCard key={k.id} kpi={k} />
            ))}
          </div>
          )}

          {/* Gráficos + funil (Meteórico/Padrão; SEAL não tem) */}
          {view !== 'seal' && view !== 'anuncios' && (
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
              <Funnel
                stages={funnelStages}
                cac={cacValue}
                variant={view}
                landingPageViews={data.landingPageViews}
                linkCliques={data.linkCliques}
              />
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
          {view !== 'seal' && view !== 'anuncios' && (
            <div className="mt-6 flex flex-col gap-6">
              {/* Tráfego por campanha: nas duas etapas. No Padrão, as campanhas
                  ocultas já saem na origem (fn_trafego + p_excluir, via queries.ts),
                  então aqui é a lista pronta. */}
              <TrafficTable
                rows={data.traffic}
                onAdClick={setAdPreview}
                hideLeads={view === 'padrao'}
                showCheckout={view === 'padrao'}
              />

              {/* Página de captação (Meteórico) / de vendas (Padrão) */}
              {view === 'meteorico' ? (
                <PagesTable
                  rows={data.pages.filter((p) => /cap|forms/i.test(p.pagina))}
                  title="Desempenho página de captação"
                  colKeys={['pagina', 'pageView', 'leads', 'pesquisa']}
                />
              ) : (
                <PagesTable
                  // Reconhece a página de vendas pelo slug (vend / -pv-) OU por
                  // ter convertido. O slug sozinho não basta: a nomenclatura já
                  // mudou 3 vezes e as LPs novas (wep-lp02-h1-v1) não casam com
                  // nenhum dos dois padrões — sumiam da tabela levando junto os
                  // checkouts e as vendas. Quem converteu é página de vendas por
                  // definição, independente de como foi batizada.
                  rows={data.pages.filter(
                    (p) => /vend|-pv-/i.test(p.pagina) || p.checkout > 0 || p.vendas > 0
                  )}
                  title="Desempenho página de vendas"
                  colKeys={['pagina', 'pageView', 'checkout', 'vendas', 'checkoutVenda', 'visitaCheckout', 'visitaVenda']}
                />
              )}

              {/* Compradores linha a linha: a lupa por trás dos blocos
                  agregados acima. Só no Padrão, que é a etapa de venda. */}
              {view === 'padrao' && <BuyersTable rows={compradores} />}

              {/* Pesquisa: mesma pesquisa, título muda por etapa */}
              <PesquisaCharts
                perfil={data.perfil}
                respostas={data.pesquisaResumo.respostas}
                leads={data.pesquisaResumo.leads}
                title={view === 'padrao' ? 'Respostas dos compradores' : 'Respostas da pesquisa'}
              />

              {/* Quiz InLead: mesma estrutura da Pesquisa, dados de wep_quiz.
                  Só nas edições que usam o quiz (ver TAGS_SEM_QUIZ). */}
              {!TAGS_SEM_QUIZ.has(filters.tag ?? '') && (
                <QuizCharts
                  perfil={data.quizPerfil}
                  respostas={data.quizResumo.respostas}
                  vendas={data.quizResumo.vendas}
                />
              )}
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
      {adPreview && <AdThumbnailModal row={adPreview} onClose={() => setAdPreview(null)} />}
      {criativoAberto && (
        <CriativoModal c={criativoAberto} onClose={() => setCriativoAberto(null)} />
      )}
    </div>
  )
}
