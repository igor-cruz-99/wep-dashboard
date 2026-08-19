import type { MetaDirection } from '../utils/metaColor'

/** Cartão de KPI do topo (valor, meta e direção da cor). */
export interface Kpi {
  id: string
  label: string
  value: number
  /** Meta do KPI. Ausente = card só com o valor (sem %meta, seta ou barra). */
  meta?: number
  /** Como exibir o valor. */
  format: 'int' | 'brl' | 'pct'
  /** Direção da cor da %meta. CAC é 'inverse'. */
  direction: MetaDirection
  /**
   * Card sem valor calculável no contexto atual → mostra "—" em vez do número.
   * (ex.: métrica sem dimensão de origem num recorte parcial, ou grupo ainda
   * não criado). A nota exibida vem de `naNote`.
   */
  na?: boolean
  /** Texto sob o "—" quando na=true. Default: "sem recorte por origem". */
  naNote?: string
  /**
   * Percentual exibido ao lado do valor principal e usado na comparação com a
   * meta — para cards em que o número absoluto e o percentual dizem coisas
   * diferentes. Ex.: Entrada Grupo mostra "71" (pessoas no grupo) com "102,9%"
   * ao lado (entradas ÷ vendas), e é esse percentual, não o 71, que se compara
   * com a meta de 80%. Sem este campo, a meta é comparada com `value`.
   */
  pctLado?: number
}

/**
 * Criativo na galeria de anúncios: a peça com seu desempenho no período,
 * somando todas as campanhas em que rodou. Só existe para criativo com mídia
 * já sincronizada do Drive.
 */
export interface CriativoGaleria {
  adName: string
  tipo: string
  url: string | null
  videoUrl: string | null
  investimento: number
  vendas: number
  checkouts: number
  cac: number
  /** Em quantas campanhas a peça rodou — um CAC alto pode ser de uma delas só. */
  campanhas: number
}

/** Recorte por origem da captação (teste A/B: páginas vs formulário nativo). */
export type Origem = 'todas' | 'pagina' | 'nativo'

/** Linha da tabela "Origem dos Leads": de qual página/forms veio, quantos e %. */
export interface OrigemLeadRow {
  origem: string
  leads: number
  pct: number
}

/** CPL de uma origem (investimento ÷ leads daquele lado). */
export interface CplOrigemLado {
  investimento: number
  leads: number
  cpl: number
}

/** Card "CPL por origem": Páginas x Formulário nativo. */
export interface CplOrigem {
  pagina: CplOrigemLado
  nativo: CplOrigemLado
}

/** Pizza "Tráfego x Orgânico": leads por origem de aquisição (utm_campaign). */
export interface TrafegoOrganico {
  trafego: number
  organico: number
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
  /** Id real do anúncio na Meta — usado pra buscar a thumbnail no popup. */
  adId: string | null
  investimento: number
  vendas: number
  checkout: number
  leads: number
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
  leads: number
  pesquisa: number
}

/** Uma fatia/barra de um gráfico de perfil (categoria + contagem). */
export interface PerfilDatum {
  categoria: string
  total: number
}

/** Distribuições das respostas da pesquisa (roadmap item 3). */
export interface PesquisaPerfil {
  renda: PerfilDatum[]
  idade: PerfilDatum[]
  profissao: PerfilDatum[]
  genero: PerfilDatum[]
}

/** Distribuições das respostas do Quiz InLead (campanha ls-WEP-WEPAGO26-QUIZ-*). */
export interface QuizPerfil {
  origemQuiz: PerfilDatum[] // id_forms — versão do formulário
  profissao: PerfilDatum[]
  renda: PerfilDatum[]
  alguemNaRede: PerfilDatum[]
  jaDeuConselhos: PerfilDatum[]
  querAprender: PerfilDatum[]
}

/** Uma situação de pagamento do SEAL (card): quantos alunos e valor somado. */
export interface SealSituacao {
  alunos: number
  valorTotal: number
}

/** Resumo do SEAL para os 2 cards (roadmap item 2). */
export interface SealResumo {
  quitou: SealSituacao
  reserva: SealSituacao
}

/** Linha da tabela de compradores SEAL (detalhada). */
export interface SealComprador {
  email: string
  nome: string | null
  situacao: string
  data: string | null
  hora: string | null
  utmSource: string | null
  utmCampaign: string | null
  utmMedium: string | null
  utmContent: string | null
  utmTerm: string | null
  utmPagina: string | null
}

/**
 * Linha da tabela "Vendas / Por compradores": uma venda aprovada, com as UTMs
 * inteiras. `pagina` já vem no mesmo slug da tabela de desempenho, para dar
 * para cruzar as duas a olho.
 */
export interface Comprador {
  id: number
  nome: string | null
  email: string | null
  data: string | null
  hora: string | null
  valor: number
  produto: string | null
  pagina: string | null
  utmSource: string | null
  utmMedium: string | null
  utmCampaign: string | null
  utmTerm: string | null
  utmContent: string | null
}

/** Filtros globais do painel. */
export interface Filters {
  tag: string | null
  from: string
  to: string
  /** Recorte por origem da captação: 'todas' | 'pagina' | 'nativo'. */
  origem: Origem
  /** Grupo de WhatsApp da etapa: 'pre_venda' (Meteórico) | 'padrao' (Padrão). */
  grupo: 'pre_venda' | 'padrao'
  campanha: string | null
  conjunto: string | null
  anuncio: string | null
}
