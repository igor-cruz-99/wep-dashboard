/**
 * Resolve o fileId dos criativos do catálogo, casando o NOME do arquivo que a
 * planilha indica com o conteúdo da pasta do Drive.
 *
 * Por que existe, se o workflow do n8n já deveria fazer isso: em 10/09/26 os 8
 * criativos novos entraram no catálogo com a pasta e o nome do arquivo certos,
 * mas sem fileId — e sem fileId eles não entram na fila de mídia, então somem
 * da galeria. Reprocessar o fluxo atualizou os nomes e não resolveu os ids.
 * Este script destrava esse passo sem depender do n8n.
 *
 * É idempotente: só toca em quem está sem id, e casa por nome exato (ignorando
 * caixa e espaços nas pontas). Não inventa correspondência — se o arquivo não
 * estiver na pasta com aquele nome, a linha fica como está e é reportada.
 *
 * Uso (da pasta WEP - DASHBOARD):
 *   node scripts/resolve-drive-fileid.mjs          # aplica
 *   node scripts/resolve-drive-fileid.mjs --dry    # só mostra o que faria
 */
import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'

const DRY = process.argv.includes('--dry')
/**
 * Por padrão só mexe em criativo que AINDA NÃO TEM MÍDIA — são os que a galeria
 * está deixando de fora. Resolver o id de quem já foi sincronizado só o
 * devolveria para a fila e faria baixar de novo, às vezes gigabytes de vídeo,
 * sem mudar nada na tela. `--todos` levanta essa trava.
 */
const TODOS = process.argv.includes('--todos')

/**
 * A planilha marca célula vazia com "-" (e variações). Tratar isso como nome de
 * arquivo faz o relatório acusar dezenas de "arquivo faltando" que não existem
 * — o campo é que está em branco.
 */
const nomeVazio = (s) => {
  const v = String(s ?? '').trim()
  return v === '' || /^-+$/.test(v) || /^(n\/?a|nao|não|sem)$/i.test(v)
}

const env = Object.fromEntries(
  readFileSync('.env.local', 'utf8')
    .split('\n')
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => {
      const i = l.indexOf('=')
      return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')]
    })
)

const mkt = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE, {
  db: { schema: 'mkt_wep' },
  auth: { persistSession: false },
})

// ── Drive autenticado (mesma conta do drive-auth.mjs) ───────────────────────
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
const tk = await r.json()
if (!tk.access_token) {
  console.error('falha ao renovar o token do Google:', tk.error ?? '', tk.error_description ?? '')
  console.error('rode: node scripts/drive-auth.mjs')
  process.exit(1)
}
const H = { Authorization: `Bearer ${tk.access_token}` }

/** Lista uma pasta inteira (pagina até o fim). Cacheado: pastas se repetem. */
const cachePastas = new Map()
async function listarPasta(folderId) {
  if (cachePastas.has(folderId)) return cachePastas.get(folderId)
  const arquivos = []
  let pageToken
  do {
    const q = encodeURIComponent(`'${folderId}' in parents and trashed=false`)
    const url =
      `https://www.googleapis.com/drive/v3/files?q=${q}` +
      `&fields=nextPageToken,files(id,name,size)&pageSize=200` +
      `&supportsAllDrives=true&includeItemsFromAllDrives=true` +
      (pageToken ? `&pageToken=${pageToken}` : '')
    const res = await fetch(url, { headers: H })
    if (!res.ok) throw new Error(`Drive ${res.status}: ${(await res.text()).slice(0, 160)}`)
    const j = await res.json()
    arquivos.push(...(j.files ?? []))
    pageToken = j.nextPageToken
  } while (pageToken)
  cachePastas.set(folderId, arquivos)
  return arquivos
}

const chave = (s) => String(s ?? '').trim().toLowerCase()

const { data: cat, error } = await mkt.from('criativos_drive').select('*').limit(5000)
if (error) {
  console.error('não consegui ler o catálogo:', error.message)
  process.exit(1)
}

// Só quem tem pasta, tem nome de arquivo e ainda não tem o id correspondente.
const temMidia = (c) => Boolean(c.storage_url || c.storage_video_url)
const pendentes = cat.filter(
  (c) =>
    c.drive_folder_id &&
    (TODOS || !temMidia(c)) &&
    ((!nomeVazio(c.arquivo_feed) && !c.drive_feed_id) ||
      (!nomeVazio(c.arquivo_story) && !c.drive_story_id))
)

console.log(
  `catálogo: ${cat.length} linhas | a resolver: ${pendentes.length}` +
    (TODOS ? '  (--todos: inclui quem já tem mídia)' : '  (só quem ainda não tem mídia)')
)
if (DRY) console.log('(modo --dry: nada será gravado)\n')
else console.log('')

let resolvidos = 0
const naoAchados = []

for (const c of pendentes) {
  let arquivos
  try {
    arquivos = await listarPasta(c.drive_folder_id)
  } catch (e) {
    console.log(`  !! ${c.ad_name.slice(0, 50)} — ${e.message}`)
    continue
  }
  const porNome = new Map(arquivos.map((f) => [chave(f.name), f]))

  const patch = {}
  for (const [campoArquivo, campoId] of [
    ['arquivo_feed', 'drive_feed_id'],
    ['arquivo_story', 'drive_story_id'],
  ]) {
    const nome = c[campoArquivo]
    if (nomeVazio(nome) || c[campoId]) continue
    const achado = porNome.get(chave(nome))
    if (achado) patch[campoId] = achado.id
    else naoAchados.push([c.ad_name, nome, arquivos.length])
  }

  if (!Object.keys(patch).length) continue

  if (DRY) {
    console.log(`  -> ${c.ad_name.slice(0, 50)}  ${Object.keys(patch).join(', ')}`)
    resolvidos++
    continue
  }

  const { error: eUp } = await mkt.from('criativos_drive').update(patch).eq('ad_name', c.ad_name)
  if (eUp) console.log(`  !! ${c.ad_name.slice(0, 50)} — falha ao gravar: ${eUp.message}`)
  else {
    console.log(`  ok ${c.ad_name.slice(0, 50)}  ${Object.keys(patch).join(', ')}`)
    resolvidos++
  }
}

console.log(`\nresumo: ${resolvidos} criativo(s) com fileId resolvido`)
if (naoAchados.length) {
  console.log(`\n${naoAchados.length} arquivo(s) que a planilha cita e NÃO existem na pasta:`)
  for (const [ad, nome, n] of naoAchados)
    console.log(`  ${ad.slice(0, 45)}\n     procurado: ${nome}  (a pasta tem ${n} arquivos)`)
}

const { data: pend } = await mkt.rpc('fn_criativos_drive_pendentes')
console.log(`\nfila de mídia agora: ${pend?.length ?? 0} itens`)
