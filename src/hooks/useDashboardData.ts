import { useEffect, useState } from 'react'
import {
  fetchCplOrigem,
  fetchFunnel,
  fetchKpis,
  fetchOrigemLeads,
  fetchPages,
  fetchPesquisaPerfil,
  fetchTrafegoOrganico,
  fetchSealCompradores,
  fetchSealResumo,
  fetchSeries,
  fetchTraffic,
} from '../lib/queries'
import type {
  CplOrigem,
  TrafegoOrganico,
  DailyPoint,
  Filters,
  FunnelStage,
  Kpi,
  OrigemLeadRow,
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
  origemLeads: OrigemLeadRow[]
  cplOrigem: CplOrigem
  trafegoOrganico: TrafegoOrganico
  perfil: PesquisaPerfil
  /** Resumo do bloco Pesquisa: nº de respostas e % sobre os leads. */
  pesquisaResumo: { respostas: number; leads: number }
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
 * TODOS os blocos respeitam o filtro de período — inclusive o SEAL, que filtra
 * pela data da compra (core.vendas_pagarme.data). O SEAL não usa tag porque
 * vendas_pagarme não tem essa coluna; só período.
 *
 * Sem dados fictícios: enquanto carrega, data = null (loading); em erro,
 * data = null e a mensagem fica em `error`.
 */
export function useDashboardData(filters: Filters): State {
  const [state, setState] = useState<State>({ data: null, loading: true, error: null })

  useEffect(() => {
    let cancelled = false
    setState((s) => ({ ...s, loading: true, error: null }))

    Promise.all([
      fetchKpis(filters),
      fetchFunnel(filters),
      fetchSeries(filters),
      fetchTraffic(filters),
      fetchPages(filters),
      fetchOrigemLeads(filters),
      fetchCplOrigem(filters),
      fetchTrafegoOrganico(filters),
      fetchPesquisaPerfil(filters),
      fetchSealResumo(filters),
      fetchSealCompradores(filters),
    ])
      .then(([kpiRes, funnel, series, traffic, pages, origemLeads, cplOrigem, trafegoOrganico, perfil, seal, sealCompradores]) => {
        if (cancelled) return
        setState({
          data: {
            kpis: kpiRes.cards,
            funnel,
            series,
            traffic,
            pages,
            origemLeads,
            cplOrigem,
            trafegoOrganico,
            perfil,
            pesquisaResumo: { respostas: kpiRes.respostasPesquisa, leads: kpiRes.leads },
            seal,
            sealCompradores,
          },
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
