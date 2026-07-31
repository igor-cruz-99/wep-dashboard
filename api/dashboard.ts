/**
 * "Porteiro" do dashboard — roda no servidor (Vercel), nunca no navegador.
 *
 * Fluxo:
 *   1. Recebe o token do usuário logado (projeto de AUTH dos funcionários).
 *   2. Valida esse token no projeto de auth. Inválido → 401 e nada mais.
 *   3. Só então consulta o projeto de DADOS usando a service_role.
 *
 * A service_role fica só aqui (variável de ambiente sem prefixo VITE_),
 * então nunca vai parar no bundle do navegador.
 */
import { createClient } from '@supabase/supabase-js'

// Declarado localmente para não depender de @types/node estar carregado no
// contexto em que a Vercel compila as funções (evita "Cannot find name 'process'").
declare const process: { env: Record<string, string | undefined> }

const DATA_URL = process.env.SUPABASE_URL ?? process.env.VITE_SUPABASE_URL
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE
const AUTH_URL = process.env.SUPABASE_AUTH_URL ?? process.env.VITE_SUPABASE_AUTH_URL
const AUTH_ANON = process.env.SUPABASE_AUTH_ANON_KEY ?? process.env.VITE_SUPABASE_AUTH_ANON_KEY

/** Operações permitidas — impede chamar RPC arbitrária pela API. */
const ALLOWED_RPC = new Set([
  'fn_kpis',
  'fn_funil',
  'fn_serie_diaria',
  'fn_serie_grupo',
  'fn_trafego',
  'fn_paginas',
  'fn_pesquisa_perfil',
  'fn_origem_leads',
  'fn_cpl_origem',
  'fn_trafego_organico',
  'fn_seal_resumo',
  'fn_seal_compradores',
])

interface Req {
  method?: string
  headers: Record<string, string | string[] | undefined>
  body?: { fn?: string; params?: Record<string, unknown> }
}
interface Res {
  status: (code: number) => Res
  json: (body: unknown) => void
}

// Quem pode acessar o painel. O login com Google cria conta automaticamente,
// então "estar logado" NÃO basta — é preciso estar autorizado aqui.
const ALLOWED_EMAILS = (process.env.DASHBOARD_ALLOWED_EMAILS ?? '')
  .split(',')
  .map((e) => e.trim().toLowerCase())
  .filter(Boolean)
const ALLOWED_DOMAINS = (process.env.DASHBOARD_ALLOWED_DOMAINS ?? '')
  .split(',')
  .map((d) => d.trim().toLowerCase().replace(/^@/, ''))
  .filter(Boolean)

/** Devolve o email do dono do token, ou null se o token for inválido. */
async function getUserEmail(token: string): Promise<string | null> {
  try {
    const r = await fetch(`${AUTH_URL}/auth/v1/user`, {
      headers: { apikey: AUTH_ANON as string, Authorization: `Bearer ${token}` },
    })
    if (!r.ok) return null
    const user = (await r.json()) as { email?: string }
    return user.email?.toLowerCase() ?? null
  } catch {
    return null
  }
}

/**
 * Interruptor de desenvolvimento — pula a validação de sessão para ajustar o
 * visual sem login. A trava `NODE_ENV !== 'production'` é o que torna isso
 * impossível de ligar na Vercel, mesmo que a variável seja definida lá por engano.
 */
const DEV_SKIP_AUTH =
  process.env.DEV_SKIP_AUTH === '1' && process.env.NODE_ENV !== 'production'

/** Email está na allowlist (por email exato ou por domínio)? */
function isAllowed(email: string): boolean {
  if (ALLOWED_EMAILS.includes(email)) return true
  const domain = email.split('@')[1] ?? ''
  return ALLOWED_DOMAINS.includes(domain)
}

export default async function handler(req: Req, res: Res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método não permitido' })

  if (!DATA_URL || !SERVICE_ROLE || !AUTH_URL || !AUTH_ANON) {
    return res.status(500).json({ error: 'Servidor sem as variáveis de ambiente configuradas.' })
  }

  // Sem allowlist configurada, ninguém entra (falha fechada, nunca aberta).
  if (!DEV_SKIP_AUTH && ALLOWED_EMAILS.length === 0 && ALLOWED_DOMAINS.length === 0) {
    return res.status(500).json({
      error:
        'Allowlist não configurada. Defina DASHBOARD_ALLOWED_EMAILS e/ou DASHBOARD_ALLOWED_DOMAINS.',
    })
  }

  if (!DEV_SKIP_AUTH) {
    // 1) Token do usuário
    const raw = req.headers.authorization
    const header = Array.isArray(raw) ? raw[0] : raw
    const token = header?.startsWith('Bearer ') ? header.slice(7) : ''
    if (!token) return res.status(401).json({ error: 'Sem token de sessão.' })

    // 2) Validação no projeto de auth
    const email = await getUserEmail(token)
    if (!email) return res.status(401).json({ error: 'Sessão inválida ou expirada.' })

    // 3) Autorização — logar não basta, tem que estar na allowlist
    if (!isAllowed(email)) {
      return res.status(403).json({ error: 'Sua conta não tem acesso a este painel.' })
    }
  }

  // 3) Consulta ao projeto de dados com service_role (só no servidor)
  const db = createClient(DATA_URL, SERVICE_ROLE, {
    db: { schema: 'mkt_wep' },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const fn = req.body?.fn
  const params = req.body?.params ?? {}

  try {
    if (fn === 'tags') {
      const { data, error } = await db
        .from('vw_tags')
        .select('tag, inicio_cap, final_cap')
        .order('tag')
      if (error) throw error
      return res.status(200).json({ data })
    }

    if (!fn || !ALLOWED_RPC.has(fn)) {
      return res.status(400).json({ error: 'Operação não permitida.' })
    }

    const { data, error } = await db.rpc(fn, params)
    if (error) throw error
    return res.status(200).json({ data })
  } catch (err) {
    const message = (err as { message?: string })?.message ?? 'Erro ao consultar os dados.'
    return res.status(500).json({ error: message })
  }
}
