import type { MetaDirection } from '../utils/metaColor'

/** Cartão de KPI do topo (valor, meta e direção da cor). */
export interface Kpi {
  id: string
  label: string
  value: number
  meta: number
  /** Como exibir o valor. */
  format: 'int' | 'brl' | 'pct'
  /** Direção da cor da %meta. CAC é 'inverse'. */
  direction: MetaDirection
}

/** Ponto de uma série diária (gráficos de linha). */
export interface DailyPoint {
  date: string // YYYY-MM-DD
  value: number
}

/** Etapa do funil. */
export interface FunnelStage {
  label: string
  value: number
  format: 'int' | 'brl'
}

/** Linha da tabela "Análise de tráfego". */
export interface TrafficRow {
  id: string
  nivel: 'campanha' | 'conjunto' | 'anuncio'
  nome: string
  /** Chaves para o cruzamento entre as 3 tabelas (campanha → conjunto → anúncio). */
  campanha: string | null
  conjunto: string | null
  anuncio: string | null
  investimento: number
  vendas: number
  cac: number
  qualificacao: number
  hook: number // % retenção inicial
  hold: number // % retenção ao longo
  body: number // % corpo do vídeo
}

/** Linha da tabela "Páginas". */
export interface PageRow {
  id: string
  pagina: string
  pageView: number
  checkout: number
  vendas: number
  pesquisa: number
}

/** Filtros globais do painel. */
export interface Filters {
  tag: string | null
  from: string
  to: string
  campanha: string | null
  conjunto: string | null
  anuncio: string | null
}
