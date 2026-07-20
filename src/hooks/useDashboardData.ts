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
    investimentoPorDia: DailyPoint[]
    conversaoPorDia: DailyPoint[]
  }
  traffic: TrafficRow[]
  pages: PageRow[]
  perfil: PesquisaPerfil
  seal: SealResumo
  sealCompradores: SealComprador[]
}

interface State {
  data: DashboardData | null
  loading: boolean
  error: string | null
}

/**
 * Carrega todos os blocos do painel via API /api/dashboard, reagindo aos filtros.
 * Sem dados fictícios: enquanto carrega, data = null (loading); em erro,
 * data = null e a mensagem fica em `error`.
 */
export function useDashboardData(filters: Filters): State {
  const [state, setState] = useState<State>({
    data: null,
    loading: true,
    error: null,
  })

  useEffect(() => {
    let cancelled = false
    setState((s) => ({ ...s, loading: true, error: null }))

    // Paralelo: com o índice trgm no ads_metrics cada RPC é rápida (~300ms) e
    // não há mais risco de timeout por contenção.
    Promise.all([
      fetchKpis(filters),
      fetchFunnel(filters),
      fetchSeries(filters),
      fetchTraffic(filters),
      fetchPages(filters),
      fetchPesquisaPerfil(filters),
      fetchSealResumo(),
      fetchSealCompradores(),
    ])
      .then(([kpis, funnel, series, traffic, pages, perfil, seal, sealCompradores]) => {
        if (cancelled) return
        setState({
          data: { kpis, funnel, series, traffic, pages, perfil, seal, sealCompradores },
          loading: false,
          error: null,
        })
      })
      .catch((err) => {
        if (cancelled) return
        setState({
          data: null,
          loading: false,
          error: (err as { message?: string })?.message ?? 'Erro ao carregar dados do Supabase.',
        })
      })

    return () => {
      cancelled = true
    }
  }, [filters])

  return state
}
