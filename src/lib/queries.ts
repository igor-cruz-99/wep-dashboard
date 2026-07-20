import { supabaseAuth } from './supabase'
import type {
  DailyPoint,
  FunnelStage,
  Kpi,
  PageRow,
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
 * Chama o "porteiro" (/api/dashboard) mandando o token da sessão.
 * O servidor valida a sessão e só então consulta o banco — o navegador
 * nunca fala direto com o Supabase de dados.
 */
async function callApi<T>(fn: string, params?: Record<string, unknown>): Promise<T> {
  if (!supabaseAuth) throw new Error('Auth não configurado')
  const { data } = await supabaseAuth.auth.getSession()
  const token = data.session?.access_token
  if (!token) throw new Error('Sessão expirada. Faça login novamente.')

  const res = await fetch('/api/dashboard', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
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
  meta_vendas: number
  meta_faturamento: number
  meta_cac: number
  meta_grupo: number
  meta_qualificacao: number
}
interface FunilRow { etapa: string; valor: number; ordem: number }
interface SerieRow { data: string; vendas: number; investimento: number; cac: number; conversao: number }
interface TrafegoRow {
  nivel: TrafficRow['nivel']
  campanha: string | null
  conjunto: string | null
  anuncio: string | null
  investimento: number
  vendas: number
  cac: number
  hook: number
  hold: number
  body: number
}
interface PaginaRow { pagina: string; page_views: number; checkouts: number; vendas: number }

// ── KPIs ──────────────────────────────────────────────────────────────────
export async function fetchKpis(filters: Filters): Promise<Kpi[]> {
  const data = await callApi<KpiRow[]>('fn_kpis', rpcParams(filters))
  const r = (data?.[0] ?? {}) as Partial<KpiRow>
  const num = (v: number | undefined) => Number(v ?? 0)

  const grupoPct = num(r.entradas_grupo) > 0 ? (num(r.vendas_count) / num(r.entradas_grupo)) * 100 : 0
  const qualifPct = num(r.pesquisas) > 0 ? (num(r.qualificados) / num(r.pesquisas)) * 100 : 0

  return [
    { id: 'vendas', label: 'Vendas Ingressos', value: num(r.vendas_count), meta: num(r.meta_vendas), format: 'int', direction: 'normal' },
    { id: 'faturamento', label: 'Faturamento', value: num(r.faturamento), meta: num(r.meta_faturamento), format: 'brl', direction: 'normal' },
    { id: 'cac', label: 'CAC', value: num(r.cac), meta: num(r.meta_cac), format: 'brl', direction: 'inverse' },
    { id: 'grupo', label: 'Entrada Grupo', value: grupoPct, meta: num(r.meta_grupo), format: 'pct', direction: 'normal' },
    { id: 'qualificacao', label: 'Qualificação', value: qualifPct, meta: num(r.meta_qualificacao), format: 'pct', direction: 'normal' },
  ]
}

// ── Funil ───────────────────────────────────────────────────────────────────
export async function fetchFunnel(filters: Filters): Promise<FunnelStage[]> {
  const data = await callApi<FunilRow[]>('fn_funil', rpcParams(filters))
  return (data ?? []).map((r) => ({
    label: r.etapa,
    value: Number(r.valor),
    format: r.etapa === 'Investimento' ? 'brl' : 'int',
  }))
}

// ── Séries diárias (4 gráficos) ─────────────────────────────────────────────
export async function fetchSeries(filters: Filters): Promise<{
  vendasPorDia: DailyPoint[]
  cacPorDia: DailyPoint[]
  investimentoPorDia: DailyPoint[]
  conversaoPorDia: DailyPoint[]
}> {
  const rows = (await callApi<SerieRow[]>('fn_serie_diaria', rpcParams(filters))) ?? []
  const pick = (key: keyof SerieRow): DailyPoint[] =>
    rows.map((r) => ({ date: r.data, value: Number(r[key]) }))
  return {
    vendasPorDia: pick('vendas'),
    cacPorDia: pick('cac'),
    investimentoPorDia: pick('investimento'),
    conversaoPorDia: pick('conversao'),
  }
}

// ── Análise de tráfego ──────────────────────────────────────────────────────
export async function fetchTraffic(filters: Filters): Promise<TrafficRow[]> {
  const data = await callApi<TrafegoRow[]>('fn_trafego', {
    p_from: filters.from || null,
    p_to: filters.to || null,
  })
  return (data ?? []).map((r, i) => ({
    id: `${r.campanha ?? ''}|${r.conjunto ?? ''}|${r.anuncio ?? ''}|${i}`,
    nivel: r.nivel,
    nome: r.anuncio ?? r.conjunto ?? r.campanha ?? '—',
    campanha: r.campanha,
    conjunto: r.conjunto,
    anuncio: r.anuncio,
    investimento: Number(r.investimento),
    vendas: Number(r.vendas),
    cac: Number(r.cac),
    qualificacao: 0, // N/A por campanha (pesquisa não tem UTM) — ver pendência
    hook: Number(r.hook),
    hold: Number(r.hold),
    body: Number(r.body),
  }))
}

// ── Páginas ─────────────────────────────────────────────────────────────────
export async function fetchPages(filters: Filters): Promise<PageRow[]> {
  const data = await callApi<PaginaRow[]>('fn_paginas', {
    p_from: filters.from || null,
    p_to: filters.to || null,
  })
  return (data ?? []).map((r) => ({
    id: r.pagina,
    pagina: r.pagina,
    pageView: Number(r.page_views),
    checkout: Number(r.checkouts),
    vendas: Number(r.vendas),
    pesquisa: 0, // pesquisa não é por página no modelo atual — ver pendência
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
