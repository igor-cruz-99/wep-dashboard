/**
 * Sincroniza a mídia dos criativos: Drive -> Supabase Storage.
 *
 * Por que existe, se já há um workflow no n8n: o "payload too large" que o n8n
 * mostrava era o 413 do próprio Supabase sendo repassado — os vídeos no Drive
 * são masters de edição (um deles tem 1 GB) e o Storage recusa acima de 50 MB.
 * O n8n não tinha culpa. Este script existe porque resolve o caso dos arquivos
 * grandes (sobe a capa em vez do vídeo) e roda a fila inteira de uma vez.
 *
 * Acessa o Drive autenticado com a sua conta (as pastas são privadas por
 * política do Workspace e não podem ser liberadas por link). Rode antes, uma
 * única vez:  node scripts/drive-auth.mjs
 *
 * Uso (da pasta WEP - DASHBOARD):
 *   node scripts/sync-criativos-drive.mjs           # processa a fila inteira
 *   node scripts/sync-criativos-drive.mjs 5         # processa só os 5 primeiros
 */
import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'

const env = Object.fromEntries(
  readFileSync('.env.local', 'utf8')
    .split('\n')
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => {
      const i = l.indexOf('=')
      return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')]
    })
)

const SUPABASE_URL = env.SUPABASE_URL
const KEY = env.SUPABASE_SERVICE_ROLE
const BUCKET = 'ad-creatives'
const LIMITE = Number(process.argv[2]) || 500

const mkt = createClient(SUPABASE_URL, KEY, {
  db: { schema: 'mkt_wep' },
  auth: { persistSession: false },
})

const extDe = (mime) =>
  mime.startsWith('video/')
    ? (mime.includes('quicktime') ? 'mov' : 'mp4')
    : mime.includes('png')
      ? 'png'
      : mime.includes('gif')
        ? 'gif'
        : 'jpg'

/** Troca o refresh token por um access token (vale ~1h, cabe a fila inteira). */
async function pegarAccessToken() {
  const faltando = ['GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET', 'GOOGLE_REFRESH_TOKEN'].filter((k) => !env[k])
  if (faltando.length) {
    console.error(`Faltam no .env.local: ${faltando.join(', ')}`)
    console.error('Rode primeiro:  node scripts/drive-auth.mjs')
    process.exit(1)
  }
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      refresh_token: env.GOOGLE_REFRESH_TOKEN,
      grant_type: 'refresh_token',
    }),
  })
  const j = await r.json()
  if (!j.access_token) {
    console.error('Não consegui renovar o token:', JSON.stringify(j).slice(0, 200))
    console.error('Rode de novo:  node scripts/drive-auth.mjs')
    process.exit(1)
  }
  return j.access_token
}

const ACCESS_TOKEN = await pegarAccessToken()

// O Storage recusa acima de 50 MB (413 EntityTooLarge — testado: 50 passa,
// 55 não). Os vídeos no Drive são masters de edição, chegando a 1 GB, então
// para eles subimos a capa que o próprio Drive gera em vez do arquivo.
const LIMITE_BYTES = 48 * 1024 * 1024 // margem sobre os 50 MB

/** Metadados do arquivo: tamanho, tipo e link da capa. */
async function metadados(fileId) {
  const r = await fetch(
    `https://www.googleapis.com/drive/v3/files/${fileId}?fields=name,size,mimeType,thumbnailLink&supportsAllDrives=true`,
    { headers: { Authorization: `Bearer ${ACCESS_TOKEN}` } }
  )
  if (!r.ok) return { erro: `drive meta ${r.status}` }
  return await r.json()
}

/**
 * Baixa o arquivo pela API do Drive, autenticado.
 * Se passar do limite do Storage, baixa a capa em alta resolução — o
 * thumbnailLink vem com sufixo de tamanho (=s220) que trocamos por s1600.
 */
async function baixarDoDrive(fileId) {
  const meta = await metadados(fileId)
  if (meta.erro) return { erro: meta.erro }

  const tamanho = Number(meta.size || 0)
  const grande = tamanho > LIMITE_BYTES

  if (grande) {
    if (!meta.thumbnailLink) {
      return { erro: `arquivo de ${(tamanho / 1048576).toFixed(0)} MB e sem capa disponivel` }
    }
    const urlCapa = meta.thumbnailLink.replace(/=s\d+$/, '=s1600')
    const r = await fetch(urlCapa, { headers: { Authorization: `Bearer ${ACCESS_TOKEN}` } })
    if (!r.ok) return { erro: `capa ${r.status}` }
    const buf = Buffer.from(await r.arrayBuffer())
    if (buf.length === 0) return { erro: 'capa vazia' }
    return { buf, mime: 'image/jpeg', capaDe: (tamanho / 1048576).toFixed(0) }
  }

  try {
    const r = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}?alt=media&supportsAllDrives=true`, {
      headers: { Authorization: `Bearer ${ACCESS_TOKEN}` },
      redirect: 'follow',
    })
    if (!r.ok) {
      const txt = await r.text()
      return { erro: `drive ${r.status}: ${txt.slice(0, 120)}` }
    }
    const mime = (r.headers.get('content-type') || '').split(';')[0].trim()
    const buf = Buffer.from(await r.arrayBuffer())
    if (buf.length === 0) return { erro: 'arquivo vazio' }
    return { buf, mime: mime || 'application/octet-stream' }
  } catch (e) {
    return { erro: String(e.message || e).slice(0, 120) }
  }
}

async function subirNoStorage(destino, buf, mime) {
  const r = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${destino}`, {
    method: 'POST',
    headers: {
      apikey: KEY,
      Authorization: `Bearer ${KEY}`,
      'Content-Type': mime,
      'x-upsert': 'true',
      'Cache-Control': 'max-age=31536000',
    },
    body: buf,
  })
  const txt = await r.text()
  if (!r.ok) return { erro: `storage ${r.status}: ${txt.slice(0, 140)}` }
  // só confirma se o Storage devolveu a chave — nunca gravar URL por convenção
  const j = JSON.parse(txt || '{}')
  if (!j.Key && !j.Id) return { erro: `upload sem confirmacao: ${txt.slice(0, 140)}` }
  return { ok: true }
}

const patch = (adName, campos) =>
  mkt.from('criativos_drive').update(campos).eq('ad_name', adName)

const { data: fila, error } = await mkt.rpc('fn_criativos_drive_pendentes', { p_limit: LIMITE })
if (error) {
  console.error('erro ao buscar a fila:', error.message)
  process.exit(1)
}

console.log(`fila: ${fila.length} criativos\n`)
let ok = 0
let falhou = 0
let capas = 0
let bytes = 0

for (const [i, c] of fila.entries()) {
  const pos = `[${String(i + 1).padStart(3)}/${fila.length}]`
  const nome = c.ad_name.slice(0, 44).padEnd(46)

  const baixado = await baixarDoDrive(c.drive_file_id)
  if (baixado.erro) {
    await patch(c.ad_name, { erro: baixado.erro, synced_at: new Date().toISOString() })
    console.log(`${pos} ${nome} FALHA download: ${baixado.erro}`)
    falhou++
    continue
  }

  const destino = `${c.ad_name
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')}.${extDe(baixado.mime)}`

  const subido = await subirNoStorage(destino, baixado.buf, baixado.mime)
  if (subido.erro) {
    await patch(c.ad_name, { erro: subido.erro, synced_at: new Date().toISOString() })
    console.log(`${pos} ${nome} FALHA upload: ${subido.erro}`)
    falhou++
    continue
  }

  const publica = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${destino}`
  const ehVideo = baixado.mime.startsWith('video/')
  const { error: eUp } = await patch(c.ad_name, {
    [ehVideo ? 'storage_video_url' : 'storage_url']: publica,
    synced_at: new Date().toISOString(),
    erro: null,
  })
  if (eUp) {
    console.log(`${pos} ${nome} subiu mas NAO gravou: ${eUp.message}`)
    falhou++
    continue
  }

  bytes += baixado.buf.length
  ok++
  if (baixado.capaDe) capas++
  const kb = (baixado.buf.length / 1024).toFixed(0)
  const nota = baixado.capaDe ? `capa (video de ${baixado.capaDe} MB)` : baixado.mime
  console.log(`${pos} ${nome} ok  ${String(kb).padStart(6)} KB  ${nota}`)
}

console.log(
  `\nresumo: ${ok} sincronizados (${capas} como capa de vídeo grande), ` +
    `${falhou} com erro, ${(bytes / 1024 / 1024).toFixed(1)} MB transferidos`
)
