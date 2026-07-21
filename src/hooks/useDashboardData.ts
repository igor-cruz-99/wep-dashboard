import { useEffect, useState } from 'react'
import {
  fetchFunnel,
  fetchKpis,
  fetchPages,
  fetchPesquisaPerfil,
  fetchSealCompradores,
  fetchSealResumo,
  fetchSeries,
  fetchTraffic,
} from '../lib/queries'
import type {
  DailyPoint,
  Filters,
  FunnelStage,
  Kpi,
  PageRow,
  PesquisaPerfil,
  SealComprador,
  SealResumo,
  TrafficRow,
} from '../types'

export interface DashboardData {
  kpis: Kpi[]
  funnel: FunnelStage[]
  series: {
    vendasPorDia: DailyPoint[]
    cacPorDia: DailyPoint[]
    leadsPorDia: DailyPoint[]
    conversaoLeadsPorDia: DailyPoint[]
    investimentoPorDia: DailyPoint[]
    conversaoPorDia: DailyPoint[]
  }
  traffic: TrafficRow[]
  pages: PageRow[]
  perfil: PesquisaPerfil
  /** Resumo do bloco Pesquisa: nº de respostas e % sobre os leads. */
  pesquisaResumo: { respostas: number; leads: number }
  seal: SealResumo
  sealCompradores: SealComprador[]
}

/** Blocos que reagem aos filtros (tag/período). */
type FilteredData = Omit<DashboardData, 'seal' | 'sealCompradores'>
/** Blocos independentes de filtro — o SEAL é sempre todas as vendas. */
interface SealData {
  seal: SealResumo
  sealCompradores: SealComprador[]
}

interface State {
  data: DashboardData | null
  loading: boolean
  error: string | null
}

/**
 * Carrega os blocos do painel via API /api/dashboard.
 *
 * Duas fontes com cadências diferentes:
 *  - dependentes de filtro (KPIs, funil, séries, tabelas, pesquisa): recarregam
 *    a cada mudança de tag/período;
 *  - SEAL (resumo + compradores): independem de filtro, então carregam UMA vez
 *    e são reaproveitados — evita refazer a query cara em core.vendas_pagarme
 *    a cada clique de filtro.
 *
 * Sem dados fictícios: enquanto carrega, data = null (loading); em erro,
 * data = null e a mensagem fica em `error`.
 */
export function useDashboardData(filters: Filters): State {
  const [filtered, setFiltered] = useState<{
    data: FilteredData | null
    loading: boolean
    error: string | null
  }>({ data: null, loading: true, error: null })
  const [seal, setSeal] = useState<SealData | null>(null)

  // SEAL: uma vez só (não depende de filtros).
  useEffect(() => {
    let cancelled = false
    Promise.all([fetchSealResumo(), fetchSealCompradores()])
      .then(([resumo, compradores]) => {
        if (!cancelled) setSeal({ seal: resumo, sealCompradores: compradores })
      })
      .catch(() => {
        // Os fetchers já são tolerantes (retornam vazio); este catch é só rede.
        if (!cancelled) setSeal({ seal: { quitou: { alunos: 0, valorTotal: 0 }, reserva: { alunos: 0, valorTotal: 0 } }, sealCompradores: [] })
      })
    return () => {
      cancelled = true
    }
  }, [])

  // Blocos dependentes de filtro: recarregam a cada mudança.
  useEffect(() => {
    let cancelled = false
    setFiltered((s) => ({ ...s, loading: true, error: null }))

    Promise.all([
      fetchKpis(filters),
      fetchFunnel(filters),
      fetchSeries(filters),
      fetchTraffic(filters),
      fetchPages(filters),
      fetchPesquisaPerfil(filters),
    ])
      .then(([kpiRes, funnel, series, traffic, pages, perfil]) => {
        if (cancelled) return
        setFiltered({
          data: {
            kpis: kpiRes.cards,
            funnel,
            series,
            traffic,
            pages,
            perfil,
            pesquisaResumo: { respostas: kpiRes.respostasPesquisa, leads: kpiRes.leads },
          },
          loading: false,
          error: null,
        })
      })
      .catch((err) => {
        if (cancelled) return
        setFiltered({
          data: null,
          loading: false,
          error: (err as { message?: string })?.message ?? 'Erro ao carregar dados do Supabase.',
        })
      })

    return () => {
      cancelled = true
    }
  }, [filters])

  // Combina as duas fontes: só há `data` quando ambas chegaram.
  const data =
    filtered.data && seal ? { ...filtered.data, ...seal } : null
  return { data, loading: filtered.loading, error: filtered.error }
}
