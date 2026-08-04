import { supabaseAuth } from './supabase'
import { DEV_SKIP_AUTH } from './devAuth'
import type {
  CplOrigem,
  TrafegoOrganico,
  DailyPoint,
  FunnelStage,
  Kpi,
  OrigemLeadRow,
  PageRow,
  PerfilDatum,
  PesquisaPerfil,
  SealComprador,
  SealResumo,
  SealSituacao,
  TrafficRow,
  Filters,
} from '../types'

/** Converte o filtro de tag do painel ('Todas' → null) e monta os params RPC. */
function rpcParams(filters: Filters) {
  return {
    p_tag: !filters.tag || filters.tag === 'Todas' ? null : filters.tag,
    p_from: filters.from || null,
    p_to: filters.to || null,
  }
}

/**
 * Recorte de origem para a RPC. Só mandamos `p_origem` quando há recorte
 * ('pagina'/'nativo'); no 'todas' omitimos a chave — assim o painel continua
 * funcionando mesmo antes de a migração 21_origem.sql estar aplicada no banco.
 */
function origemParam(filters: Filters): { p_origem?: string } {
  return !filters.origem || filters.origem === 'todas' ? {} : { p_origem: filters.origem }
}

/** params com tag + período + recorte de origem (para as RPCs que aceitam p_origem). */
function rpcParamsO(filters: Filters) {
  return { ...rpcParams(filters), ...origemParam(filters) }
}

/**
 * Campanhas que a etapa PADRÃO esconde da página inteira (não só da tabela):
 * o ad spend delas (investimento/alcance/impressões/cliques em vw_ads_diario)
 * não deve contar em NADA no Padrão. Ex.: remarketing de lote zero.
 */
const PADRAO_CAMPANHAS_EXCLUIDAS = ['ls-WEP-WEPAGO26-p04-RMKT-lote-zero']

/**
 * Envia `p_excluir` só na etapa Padrão (identificada por grupo === 'padrao';
 * Meteórico e SEAL usam 'pre_venda'). Fora dela, omite a chave — assim o painel
 * segue funcionando mesmo antes de a migração 31 estar aplicada no banco.
 */
function excluirParam(filters: Filters): { p_excluir?: string[] } {
  return filters.grupo === 'padrao' ? { p_excluir: PADRAO_CAMPANHAS_EXCLUIDAS } : {}
}

/**
 * Chama o "porteiro" (/api/dashboard) mandando o token da sessão.
 * O servidor valida a sessão e só então consulta o banco — o navegador
 * nunca fala direto com o Supabase de dados.
 */
async function callApi<T>(fn: string, params?: Record<string, unknown>): Promise<T> {
  let token: string | undefined
  if (!DEV_SKIP_AUTH) {
    if (!supabaseAuth) throw new Error('Auth não configurado')
    const { data } = await supabaseAuth.auth.getSession()
    token = data.session?.access_token
    if (!token) throw new Error('Sessão expirada. Faça login novamente.')
  }

  const res = await fetch('/api/dashboard', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ fn, params }),
  })
  const json = (await res.json().catch(() => ({}))) as { data?: T; error?: string }
  if (!res.ok) throw new Error(json.error ?? `Erro ${res.status} ao carregar dados.`)
  return json.data as T
}

// ── Tipos das linhas retornadas pelas RPCs ────────────────────────────────
interface KpiRow {
  vendas_count: number
  faturamento: number
  investimento: number
  cac: number
  entradas_grupo: number
  pesquisas: number
  qualificados: number
  leads: number
  meta_vendas: number
  meta_faturamento: number
  meta_cac: number
  meta_grupo: number
  meta_qualificacao: number
  meta_leads: number
  meta_investimento: number
  meta_cpl: number
  base_qualificacao: number
}
interface FunilRow { etapa: string; valor: number; ordem: number }
interface SerieRow { data: string; vendas: number; investimento: number; cac: number; conversao: number; leads: number; page_views: number; pesquisa: number }
interface SerieGrupoRow { data: string; entradas: number }
interface TrafegoRow {
  nivel: TrafficRow['nivel']
  campanha: string | null
  conjunto: string | null
  anuncio: string | null
  ad_id: string | null
  investimento: number
  vendas: number
  leads: number
  cac: number
  hook: number
  hold: number
  body: number
}
interface PaginaRow { pagina: string; page_views: number; checkouts: number; vendas: number; leads: number; pesquisa: number }
interface PerfilRow { dimensao: string; categoria: string; total: number }
interface SealRow { situacao: string; alunos: number; valor_total: number }
interface SealCompradorRow {
  email: string
  nome: string | null
  situacao: string
  data: string | null
  hora: string | null
  utm_source: string | null
  utm_campaign: string | null
  utm_medium: string | null
  utm_content: string | null
  utm_term: string | null
  utm_pagina: string | null
}

// ── KPIs ──────────────────────────────────────────────────────────────────
export interface KpisResult {
  cards: Kpi[]
  /** Nº de respostas de pesquisa e de leads no filtro (para o resumo do bloco Pesquisa). */
  respostasPesquisa: number
  leads: number
  /** Entradas no grupo (bruto) — pra o card de Entrada Grupo do Padrão (÷ vendas). */
  entradasGrupo: number
}

export async function fetchKpis(filters: Filters): Promise<KpisResult> {
  const data = await callApi<KpiRow[]>('fn_kpis', {
    ...rpcParamsO(filters),
    p_grupo: filters.grupo,
    ...excluirParam(filters),
  })
  const r = (data?.[0] ?? {}) as Partial<KpiRow>
  const num = (v: number | undefined) => Number(v ?? 0)

  // Entrada Grupo = % dos leads que entraram no grupo (entradas ÷ leads).
  const grupoPct = num(r.leads) > 0 ? (num(r.entradas_grupo) / num(r.leads)) * 100 : 0
  // Qualificação = qualificados (renda >10k) ÷ base avaliável (quem respondeu a
  // pesquisa OU veio do forms nativo). Denominador vem pronto da RPC.
  const qualifPct = num(r.base_qualificacao) > 0 ? (num(r.qualificados) / num(r.base_qualificacao)) * 100 : 0
  const cpl = num(r.leads) > 0 ? num(r.investimento) / num(r.leads) : 0

  // Num recorte parcial de origem (só Páginas ou só Nativo), Vendas/CAC não são
  // atribuíveis → mostram "—". Qualificação (por lead) e Entrada Grupo (por
  // tel_8d) SÃO segmentáveis, então não levam "—".
  const semOrigem = filters.origem !== 'todas'

  const cards: Kpi[] = [
    { id: 'investimento', label: 'Investimento', value: num(r.investimento), meta: num(r.meta_investimento), format: 'brl', direction: 'inverse' },
    { id: 'leads', label: 'Leads', value: num(r.leads), meta: num(r.meta_leads), format: 'int', direction: 'normal' },
    { id: 'cpl', label: 'CPL', value: cpl, meta: num(r.meta_cpl), format: 'brl', direction: 'inverse' },
    { id: 'vendas', label: 'Vendas Ingressos', value: num(r.vendas_count), meta: num(r.meta_vendas), format: 'int', direction: 'normal', na: semOrigem },
    { id: 'cac', label: 'CAC', value: num(r.cac), meta: num(r.meta_cac), format: 'brl', direction: 'inverse', na: semOrigem },
    { id: 'grupo', label: 'Entrada Grupo', value: grupoPct, meta: num(r.meta_grupo), format: 'pct', direction: 'normal' },
    { id: 'qualificacao', label: 'Qualificação', value: qualifPct, meta: num(r.meta_qualificacao), format: 'pct', direction: 'normal' },
  ]
  return {
    cards,
    respostasPesquisa: num(r.pesquisas),
    leads: num(r.leads),
    entradasGrupo: num(r.entradas_grupo),
  }
}

// ── Funil ───────────────────────────────────────────────────────────────────
export async function fetchFunnel(filters: Filters): Promise<FunnelStage[]> {
  const data = await callApi<FunilRow[]>('fn_funil', { ...rpcParamsO(filters), ...excluirParam(filters) })
  return (data ?? []).map((r) => ({
    label: r.etapa,
    value: Number(r.valor),
    format: r.etapa === 'Investimento' ? 'brl' : 'int',
  }))
}

// ── Séries diárias (gráficos) ───────────────────────────────────────────────
export async function fetchSeries(filters: Filters): Promise<{
  vendasPorDia: DailyPoint[]
  cacPorDia: DailyPoint[]
  leadsPorDia: DailyPoint[]
  conversaoLeadsPorDia: DailyPoint[]
  investimentoPorDia: DailyPoint[]
  conversaoPorDia: DailyPoint[]
  pesquisaPorDia: DailyPoint[]
}> {
  const rows = (await callApi<SerieRow[]>('fn_serie_diaria', { ...rpcParamsO(filters), ...excluirParam(filters) })) ?? []
  const pick = (key: keyof SerieRow): DailyPoint[] =>
    rows.map((r) => ({ date: r.data, value: Number(r[key] ?? 0) }))
  return {
    vendasPorDia: pick('vendas'),
    cacPorDia: pick('cac'),
    leadsPorDia: pick('leads'),
    // Conversão do dia = Leads ÷ Page Views (%), igual à "Conversão Página" do
    // funil (conversão da captação). Calculada no front com as duas séries do dia.
    conversaoLeadsPorDia: rows.map((r) => {
      const leads = Number(r.leads ?? 0)
      const pageViews = Number(r.page_views ?? 0)
      return { date: r.data, value: pageViews > 0 ? (leads / pageViews) * 100 : 0 }
    }),
    investimentoPorDia: pick('investimento'),
    conversaoPorDia: pick('conversao'),
    pesquisaPorDia: pick('pesquisa'),
  }
}

// ── Entrada no grupo por dia (por grupo da etapa) ───────────────────────────
export async function fetchSerieGrupo(filters: Filters): Promise<DailyPoint[]> {
  let rows: SerieGrupoRow[]
  try {
    rows = (await callApi<SerieGrupoRow[]>('fn_serie_grupo', {
      p_from: filters.from || null,
      p_to: filters.to || null,
      p_grupo: filters.grupo,
    })) ?? []
  } catch (err) {
    console.warn('fn_serie_grupo indisponível:', (err as Error)?.message)
    return []
  }
  return rows.map((r) => ({ date: r.data, value: Number(r.entradas ?? 0) }))
}

// ── Análise de tráfego ──────────────────────────────────────────────────────
export async function fetchTraffic(filters: Filters): Promise<TrafficRow[]> {
  const data = await callApi<TrafegoRow[]>('fn_trafego', {
    p_from: filters.from || null,
    p_to: filters.to || null,
    ...origemParam(filters),
    ...excluirParam(filters),
  })
  return (data ?? []).map((r, i) => ({
    id: `${r.campanha ?? ''}|${r.conjunto ?? ''}|${r.anuncio ?? ''}|${i}`,
    nivel: r.nivel,
    nome: r.anuncio ?? r.conjunto ?? r.campanha ?? '—',
    campanha: r.campanha,
    conjunto: r.conjunto,
    anuncio: r.anuncio,
    adId: r.ad_id,
    investimento: Number(r.investimento),
    vendas: Number(r.vendas),
    leads: Number(r.leads ?? 0), // tolera fn_trafego antiga (sem leads) até rodar o 11_leads.sql
    cac: Number(r.cac),
    qualificacao: 0, // N/A por campanha (pesquisa não tem UTM) — ver pendência
    hook: Number(r.hook),
    hold: Number(r.hold),
    body: Number(r.body),
  }))
}

// ── Thumbnail do anúncio (popup ao clicar na tabela) ────────────────────────
interface AdThumbnailRow {
  ad_id: string
  ad_name: string | null
  thumbnail_url: string | null
  image_url: string | null
}
export interface AdThumbnail {
  adId: string
  adName: string | null
  /** URL pra exibir no popup: image_url tem preferência, cai pra thumbnail_url. */
  url: string | null
}

export async function fetchAdThumbnail(adId: string): Promise<AdThumbnail | null> {
  let rows: AdThumbnailRow[]
  try {
    rows = (await callApi<AdThumbnailRow[]>('fn_ad_thumbnail', { p_ad_id: adId })) ?? []
  } catch (err) {
    console.warn('fn_ad_thumbnail indisponível:', (err as Error)?.message)
    return null
  }
  const r = rows[0]
  if (!r) return null
  return { adId: r.ad_id, adName: r.ad_name, url: r.image_url ?? r.thumbnail_url }
}

// ── Páginas ─────────────────────────────────────────────────────────────────
export async function fetchPages(filters: Filters): Promise<PageRow[]> {
  const data = await callApi<PaginaRow[]>('fn_paginas', {
    p_from: filters.from || null,
    p_to: filters.to || null,
    ...origemParam(filters),
  })
  return (data ?? []).map((r) => ({
    id: r.pagina,
    pagina: r.pagina,
    pageView: Number(r.page_views),
    checkout: Number(r.checkouts),
    vendas: Number(r.vendas),
    leads: Number(r.leads ?? 0),
    pesquisa: Number(r.pesquisa ?? 0), // via email wep_pesquisa↔wep_cadastro (sql/28)
  }))
}

// ── Origem dos Leads (tabela: de qual página/forms, quantos e %) ────────────
// Quadro completo: NÃO aplica o recorte de origem (mostra todas as origens, o %
// é sobre o total). Só tag + período.
export async function fetchOrigemLeads(filters: Filters): Promise<OrigemLeadRow[]> {
  let data: OrigemLeadRow[]
  try {
    data = (await callApi<OrigemLeadRow[]>('fn_origem_leads', rpcParams(filters))) ?? []
  } catch (err) {
    // Bloco opcional: se a RPC (24_...sql) ainda não foi aplicada, não derruba o
    // painel — a tabela fica vazia e o resto carrega normal.
    console.warn('fn_origem_leads indisponível:', (err as Error)?.message)
    return []
  }
  return data.map((r) => ({
    origem: r.origem,
    leads: Number(r.leads ?? 0),
    pct: Number(r.pct ?? 0),
  }))
}

// ── CPL por origem (card: Páginas x Forms nativo) ───────────────────────────
interface CplOrigemRow { origem: string; investimento: number; leads: number; cpl: number }
const CPL_LADO_VAZIO = { investimento: 0, leads: 0, cpl: 0 }

export async function fetchCplOrigem(filters: Filters): Promise<CplOrigem> {
  let rows: CplOrigemRow[]
  try {
    rows = (await callApi<CplOrigemRow[]>('fn_cpl_origem', rpcParams(filters))) ?? []
  } catch (err) {
    console.warn('fn_cpl_origem indisponível:', (err as Error)?.message)
    return { pagina: { ...CPL_LADO_VAZIO }, nativo: { ...CPL_LADO_VAZIO } }
  }
  const find = (o: string) => {
    const r = rows.find((x) => x.origem === o)
    return {
      investimento: Number(r?.investimento ?? 0),
      leads: Number(r?.leads ?? 0),
      cpl: Number(r?.cpl ?? 0),
    }
  }
  return { pagina: find('pagina'), nativo: find('nativo') }
}

// ── Tráfego x Orgânico (pizza) ──────────────────────────────────────────────
interface TrafOrgRow { tipo: string; leads: number }

export async function fetchTrafegoOrganico(filters: Filters): Promise<TrafegoOrganico> {
  let rows: TrafOrgRow[]
  try {
    rows = (await callApi<TrafOrgRow[]>('fn_trafego_organico', rpcParams(filters))) ?? []
  } catch (err) {
    console.warn('fn_trafego_organico indisponível:', (err as Error)?.message)
    return { trafego: 0, organico: 0 }
  }
  const g = (t: string) => Number(rows.find((x) => x.tipo === t)?.leads ?? 0)
  return { trafego: g('trafego'), organico: g('organico') }
}

// ── Perfil das pesquisas (4 gráficos) ───────────────────────────────────────
const PERFIL_VAZIO: PesquisaPerfil = { renda: [], idade: [], profissao: [], genero: [] }

export async function fetchPesquisaPerfil(filters: Filters): Promise<PesquisaPerfil> {
  let rows: PerfilRow[]
  try {
    rows = (await callApi<PerfilRow[]>('fn_pesquisa_perfil', rpcParams(filters))) ?? []
  } catch (err) {
    // Bloco opcional: se a RPC ainda não foi aplicada no banco, não derruba o
    // painel — os gráficos mostram "sem respostas" e o resto carrega normal.
    console.warn('fn_pesquisa_perfil indisponível:', (err as Error)?.message)
    return PERFIL_VAZIO
  }
  // A RPC já devolve ordenado por total desc; só separamos por dimensão.
  const pick = (dim: string): PerfilDatum[] =>
    rows.filter((r) => r.dimensao === dim).map((r) => ({ categoria: r.categoria, total: Number(r.total) }))
  return {
    renda: pick('renda'),
    idade: pick('idade'),
    profissao: pick('profissao'),
    genero: pick('genero'),
  }
}

// ── SEAL: situação de pagamento por aluno (2 cards) ─────────────────────────
const SEAL_VAZIO: SealResumo = {
  quitou: { alunos: 0, valorTotal: 0 },
  reserva: { alunos: 0, valorTotal: 0 },
}

/** SEAL filtra pela DATA DA COMPRA (sem tag: vendas_pagarme não tem coluna tag). */
const sealParams = (filters: Filters) => ({
  p_from: filters.from || null,
  p_to: filters.to || null,
})

export async function fetchSealResumo(filters: Filters): Promise<SealResumo> {
  let rows: SealRow[]
  try {
    rows = (await callApi<SealRow[]>('fn_seal_resumo', sealParams(filters))) ?? []
  } catch (err) {
    // Bloco opcional: se a RPC/view ainda não foi aplicada, não derruba o painel.
    console.warn('fn_seal_resumo indisponível:', (err as Error)?.message)
    return SEAL_VAZIO
  }
  const find = (s: string): SealSituacao => {
    const r = rows.find((x) => x.situacao === s)
    return { alunos: Number(r?.alunos ?? 0), valorTotal: Number(r?.valor_total ?? 0) }
  }
  return { quitou: find('quitou'), reserva: find('reserva') }
}

export async function fetchSealCompradores(filters: Filters): Promise<SealComprador[]> {
  let rows: SealCompradorRow[]
  try {
    rows = (await callApi<SealCompradorRow[]>('fn_seal_compradores', sealParams(filters))) ?? []
  } catch (err) {
    console.warn('fn_seal_compradores indisponível:', (err as Error)?.message)
    return []
  }
  return rows.map((r) => ({
    email: r.email,
    nome: r.nome,
    situacao: r.situacao,
    data: r.data,
    hora: r.hora,
    utmSource: r.utm_source,
    utmCampaign: r.utm_campaign,
    utmMedium: r.utm_medium,
    utmContent: r.utm_content,
    utmTerm: r.utm_term,
    utmPagina: r.utm_pagina,
  }))
}

// ── Tags + janelas de captação (para o seletor e o período automático) ──────
export interface TagWindow {
  tag: string
  from: string | null // inicio_cap
  to: string | null // final_cap
}

interface TagRow {
  tag: string
  inicio_cap: string | null
  final_cap: string | null
}

export async function fetchTags(): Promise<TagWindow[]> {
  const data = await callApi<TagRow[]>('tags')
  return (data ?? [])
    .filter((r) => r.tag)
    .map((r) => ({ tag: r.tag, from: r.inicio_cap, to: r.final_cap }))
}
