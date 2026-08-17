/**
 * Autoriza este computador a ler o Drive com a SUA conta (uma vez só).
 *
 * Por que existe: as pastas do Drive são privadas por política do Workspace e
 * não podem ser liberadas por link. Em vez de mudar permissão, o script passa a
 * acessar o Drive autenticado como você — igual o n8n faz, só que sem o n8n no
 * caminho do arquivo (que é onde ele engasga com "payload too large").
 *
 * Guarda um refresh token no .env.local (que é gitignored). Depois disso o
 * sync roda sozinho, sem pedir login de novo.
 *
 * Antes de rodar, no Google Cloud Console → Credenciais → seu OAuth Client:
 *   adicione em "URIs de redirecionamento autorizados":  http://localhost:53682
 *
 * E no .env.local, acrescente (os valores estão no mesmo lugar do Console):
 *   GOOGLE_CLIENT_ID=...
 *   GOOGLE_CLIENT_SECRET=...
 *
 * Uso:  node scripts/drive-auth.mjs
 */
import { createServer } from 'node:http'
import { readFileSync, appendFileSync } from 'node:fs'
import { spawn } from 'node:child_process'

const PORTA = 53682
const REDIRECT = `http://localhost:${PORTA}`
const ESCOPO = 'https://www.googleapis.com/auth/drive.readonly'

const env = Object.fromEntries(
  readFileSync('.env.local', 'utf8')
    .split('\n')
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => {
      const i = l.indexOf('=')
      return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')]
    })
)

const CLIENT_ID = env.GOOGLE_CLIENT_ID
const CLIENT_SECRET = env.GOOGLE_CLIENT_SECRET

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error('Faltam GOOGLE_CLIENT_ID e/ou GOOGLE_CLIENT_SECRET no .env.local.')
  console.error('Pegue os dois no Google Cloud Console → APIs e serviços → Credenciais → seu OAuth Client.')
  process.exit(1)
}

const authUrl =
  'https://accounts.google.com/o/oauth2/v2/auth?' +
  new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT,
    response_type: 'code',
    scope: ESCOPO,
    access_type: 'offline',
    prompt: 'consent', // força vir o refresh_token mesmo se já autorizou antes
  })

console.log('Abra esta URL no navegador (ou espere ela abrir sozinha):\n')
console.log(authUrl, '\n')

// Abre o navegador padrão no Windows. A URL vai entre aspas de propósito: o
// `start` do cmd trata "&" como separador de comando e cortaria o endereço no
// primeiro parâmetro, fazendo o Google reclamar de "response_type is missing".
spawn('cmd', ['/c', `start "" "${authUrl}"`], {
  detached: true,
  stdio: 'ignore',
  windowsVerbatimArguments: true,
}).unref()

const code = await new Promise((resolve, reject) => {
  const server = createServer((req, res) => {
    const url = new URL(req.url, REDIRECT)
    const code = url.searchParams.get('code')
    const erro = url.searchParams.get('error')
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' })
    res.end(
      erro
        ? `<h2>Falhou: ${erro}</h2><p>Pode fechar esta aba.</p>`
        : '<h2>Autorizado!</h2><p>Pode fechar esta aba e voltar ao terminal.</p>'
    )
    server.close()
    erro ? reject(new Error(erro)) : resolve(code)
  })
  server.listen(PORTA)
  setTimeout(() => { server.close(); reject(new Error('tempo esgotado (5 min)')) }, 300000)
})

const r = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    code,
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    redirect_uri: REDIRECT,
    grant_type: 'authorization_code',
  }),
})

const tk = await r.json()
if (!tk.refresh_token) {
  console.error('Não veio refresh_token. Resposta:', JSON.stringify(tk).slice(0, 300))
  console.error('Se já tinha autorizado antes, revogue em myaccount.google.com/permissions e rode de novo.')
  process.exit(1)
}

appendFileSync('.env.local', `\nGOOGLE_REFRESH_TOKEN=${tk.refresh_token}\n`)
console.log('\nPronto. GOOGLE_REFRESH_TOKEN gravado no .env.local.')
console.log('Agora rode:  node scripts/sync-criativos-drive.mjs 3')
