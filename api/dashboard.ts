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

const DATA_URL = process.env.SUPABASE_URL ?? process.env.VITE_SUPABASE_URL
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE
const AUTH_URL = process.env.SUPABASE_AUTH_URL ?? process.env.VITE_SUPABASE_AUTH_URL
const AUTH_ANON = process.env.SUPABASE_AUTH_ANON_KEY ?? process.env.VITE_SUPABASE_AUTH_ANON_KEY

/** Operações permitidas — impede chamar RPC arbitrária pela API. */
const ALLOWED_RPC = new Set([
  'fn_kpis',
  'fn_funil',
  'fn_serie_diaria',
  'fn_trafego',
  'fn_paginas',
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

/** Pergunta ao projeto de auth se o token pertence a um usuário válido. */
async function isValidToken(token: string): Promise<boolean> {
  try {
    const r = await fetch(`${AUTH_URL}/auth/v1/user`, {
      headers: { apikey: AUTH_ANON as string, Authorization: `Bearer ${token}` },
    })
    return r.ok
  } catch {
    return false
  }
}

export default async function handler(req: Req, res: Res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método não permitido' })

  if (!DATA_URL || !SERVICE_ROLE || !AUTH_URL || !AUTH_ANON) {
    return res.status(500).json({ error: 'Servidor sem as variáveis de ambiente configuradas.' })
  }

  // 1) Token do usuário
  const raw = req.headers.authorization
  const header = Array.isArray(raw) ? raw[0] : raw
  const token = header?.startsWith('Bearer ') ? header.slice(7) : ''
  if (!token) return res.status(401).json({ error: 'Sem token de sessão.' })

  // 2) Validação no projeto de auth
  if (!(await isValidToken(token))) {
    return res.status(401).json({ error: 'Sessão inválida ou expirada.' })
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
