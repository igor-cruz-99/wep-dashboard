/**
 * Tira o print da HERO — o que aparece antes de rolar — de cada LP do catálogo
 * (sql/81), no celular e no desktop, e grava no Storage.
 *
 * O PONTO CENTRAL É NÃO CONTAR VISITA. Toda LP carrega GTM (GA4) e Pixel da
 * Meta. Abrir a página para fotografar registraria page view e PageView — e a
 * seção Páginas mostra justamente page views ao lado do print, então o próprio
 * print inflaria o número exibido. O rastreio é bloqueado em duas camadas:
 *   1. os domínios de rastreio não resolvem DNS (--host-resolver-rules);
 *   2. as mesmas URLs são barradas no navegador (Network.setBlockedURLs).
 *
 * E a garantia é VERIFICADA, não presumida: o script acompanha toda requisição
 * a domínio de rastreio e, se alguma receber resposta, NÃO salva o print
 * daquela página e termina com erro. Testado em 10/09/26: gtm.js e fbevents.js
 * falham com ERR_NAME_NOT_RESOLVED e nenhum /g/collect nem /tr chega a sair.
 *
 * POR QUE PROTOCOLO DE DEPURAÇÃO E NÃO `chrome --screenshot`: o Chrome de
 * desktop tem largura mínima de janela, então pedir 390px desenhava a página
 * mais larga e o print saía cortado à direita. Emular o aparelho pelo protocolo
 * dá a largura exata e respeita o viewport de celular.
 *
 * O nome do arquivo leva data e hora: o Storage serve com cache de um ano, e
 * recapturar com o mesmo nome continuaria mostrando o print antigo.
 *
 * Uso (da pasta WEP - DASHBOARD):
 *   node scripts/capturar-hero-paginas.mjs            # só páginas sem print
 *   node scripts/capturar-hero-paginas.mjs --todas    # recaptura tudo (a página mudou)
 *   node scripts/capturar-hero-paginas.mjs --local    # só salva na pasta temporária
 *   node scripts/capturar-hero-paginas.mjs --so=lp02  # filtra pelo trecho do slug
 */
import { createClient } from '@supabase/supabase-js'
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync } from 'node:fs'
import { spawn } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const TODAS = process.argv.includes('--todas')
const LOCAL = process.argv.includes('--local')
const SO = process.argv.find((a) => a.startsWith('--so='))?.slice(5) ?? null

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
const CHROME = process.env.CHROME_PATH ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe'
const PORTA = 9333
/** Folga depois do load: as animações de entrada do Elementor e as fontes. */
const ESPERA_MS = 3000

const DOMINIOS_RASTREIO = [
  'googletagmanager.com',
  'google-analytics.com',
  'analytics.google.com',
  'connect.facebook.net',
  'facebook.com',
  'doubleclick.net',
]
const RASTREIO = /googletagmanager\.com|google-analytics\.com|analytics\.google\.com|facebook\.(net|com)|doubleclick\.net/i

const APARELHOS = [
  {
    nome: 'mobile',
    coluna: 'hero_mobile_url',
    width: 390,
    height: 844,
    deviceScaleFactor: 2,
    mobile: true,
    ua: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
  },
  { nome: 'desktop', coluna: 'hero_url', width: 1440, height: 900, deviceScaleFactor: 1, mobile: false, ua: null },
]

const dormir = (ms) => new Promise((r) => setTimeout(r, ms))
const normaliza = (s) => String(s ?? '').replace(/\s+/g, ' ').trim().toLowerCase()

// ── Catálogo ────────────────────────────────────────────────────────────────
const mkt = createClient(SUPABASE_URL, KEY, { db: { schema: 'mkt_wep' }, auth: { persistSession: false } })
const { data: cat, error } = await mkt.from('paginas_catalogo').select('*').eq('ativa', true).order('pagina')
if (error) {
  console.error('não consegui ler o catálogo:', error.message)
  process.exit(1)
}
if (!LOCAL && cat.length && !('hero_mobile_url' in cat[0])) {
  console.error('a coluna hero_mobile_url ainda não existe — rode o sql/82 antes')
  process.exit(1)
}

const fila = cat
  .filter((c) => !SO || c.pagina.includes(SO))
  .filter((c) => TODAS || LOCAL || !c.hero_url || !c.hero_mobile_url)

console.log(`catálogo: ${cat.length} páginas | a capturar: ${fila.length}${LOCAL ? '  (--local: nada sobe nem é gravado)' : ''}\n`)
if (!fila.length) process.exit(0)

// ── Chrome controlado pelo protocolo de depuração ───────────────────────────
const REGRAS_DNS = DOMINIOS_RASTREIO.flatMap((d) => [`MAP ${d} ~NOTFOUND`, `MAP *.${d} ~NOTFOUND`]).join(', ')
const perfil = mkdtempSync(join(tmpdir(), 'wep-hero-'))
const chrome = spawn(
  CHROME,
  [
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--no-first-run',
    '--no-default-browser-check',
    '--mute-audio',
    `--remote-debugging-port=${PORTA}`,
    `--user-data-dir=${perfil}`,
    `--host-resolver-rules=${REGRAS_DNS}`,
    'about:blank',
  ],
  { stdio: 'ignore' }
)

function conectar(wsUrl) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl)
    let seq = 0
    const pendentes = new Map()
    const ouvintes = new Map()
    ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data)
      if (msg.id && pendentes.has(msg.id)) {
        const { ok, falha } = pendentes.get(msg.id)
        pendentes.delete(msg.id)
        if (msg.error) falha(new Error(msg.error.message))
        else ok(msg.result)
      } else if (msg.method) {
        for (const fn of ouvintes.get(msg.method) ?? []) fn(msg.params)
      }
    })
    ws.addEventListener('open', () =>
      resolve({
        enviar: (method, params = {}) =>
          new Promise((ok, falha) => {
            const id = ++seq
            pendentes.set(id, { ok, falha })
            ws.send(JSON.stringify({ id, method, params }))
          }),
        ouvir: (method, fn) => ouvintes.set(method, [...(ouvintes.get(method) ?? []), fn]),
        fechar: () => ws.close(),
      })
    )
    ws.addEventListener('error', () => reject(new Error('não consegui conectar no Chrome')))
  })
}

/** Resolve true quando o evento chega, false se estourar o tempo. */
function esperarEvento(cdp, metodo, ms) {
  return new Promise((res) => {
    let feito = false
    const t = setTimeout(() => {
      if (!feito) (feito = true), res(false)
    }, ms)
    cdp.ouvir(metodo, () => {
      if (!feito) (feito = true), clearTimeout(t), res(true)
    })
  })
}

async function subirNoStorage(destino, buf) {
  const r = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${destino}`, {
    method: 'POST',
    headers: {
      apikey: KEY,
      Authorization: `Bearer ${KEY}`,
      'Content-Type': 'image/jpeg',
      'x-upsert': 'true',
      'Cache-Control': 'max-age=31536000',
    },
    body: buf,
  })
  const txt = await r.text()
  if (!r.ok) return { erro: `storage ${r.status}: ${txt.slice(0, 140)}` }
  // só confirma se o Storage devolveu a chave — nunca gravar URL por convenção
  const j = JSON.parse(txt || '{}')
  if (!j.Key && !j.Id) return { erro: `upload sem confirmação: ${txt.slice(0, 140)}` }
  return { ok: true }
}

let falhas = 0
let vazamentos = 0
const pastaLocal = join(tmpdir(), 'wep-hero-local')
if (LOCAL) mkdirSync(pastaLocal, { recursive: true })

try {
  let versao
  for (let i = 0; i < 60 && !versao; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORTA}/json/version`)
      if (r.ok) versao = await r.json()
    } catch {
      /* ainda subindo */
    }
    if (!versao) await dormir(250)
  }
  if (!versao) throw new Error('o Chrome não abriu a porta de depuração')

  const alvo = await (await fetch(`http://127.0.0.1:${PORTA}/json/new?about:blank`, { method: 'PUT' })).json()
  const cdp = await conectar(alvo.webSocketDebuggerUrl)
  const uaDesktop = String(versao['User-Agent'] ?? '').replace('HeadlessChrome', 'Chrome')

  // Acompanhamento das requisições de rastreio da navegação corrente.
  let ids = new Set()
  let rastreio = { tentadas: 0, bloqueadas: 0, vazaram: [] }
  cdp.ouvir('Network.requestWillBeSent', (p) => {
    if (RASTREIO.test(p.request.url)) ids.add(p.requestId), rastreio.tentadas++
  })
  cdp.ouvir('Network.responseReceived', (p) => {
    if (ids.has(p.requestId)) rastreio.vazaram.push(`${p.response.status} ${p.response.url.slice(0, 80)}`)
  })
  cdp.ouvir('Network.loadingFailed', (p) => {
    if (ids.has(p.requestId)) rastreio.bloqueadas++
  })

  await cdp.enviar('Page.enable')
  await cdp.enviar('Network.enable')
  await cdp.enviar('Network.setBlockedURLs', { urls: DOMINIOS_RASTREIO.map((d) => `*${d}*`) })

  for (const c of fila) {
    const url = c.link
    const base = c.pagina.replace(/^\//, '')
    const carimbo = new Date().toISOString().replace(/[-:]/g, '').slice(0, 13)

    for (const ap of APARELHOS) {
      ids = new Set()
      rastreio = { tentadas: 0, bloqueadas: 0, vazaram: [] }
      const rotulo = `${base.slice(-32).padEnd(33)} ${ap.nome.padEnd(8)}`

      await cdp.enviar('Emulation.setDeviceMetricsOverride', {
        width: ap.width,
        height: ap.height,
        deviceScaleFactor: ap.deviceScaleFactor,
        mobile: ap.mobile,
      })
      await cdp.enviar('Emulation.setUserAgentOverride', { userAgent: ap.ua ?? uaDesktop })

      const carregou = esperarEvento(cdp, 'Page.loadEventFired', 30000)
      await cdp.enviar('Page.navigate', { url })
      const noTempo = await carregou
      await dormir(ESPERA_MS)
      await cdp.enviar('Runtime.evaluate', { expression: 'window.scrollTo(0, 0)' })
      await dormir(300)

      // A garantia: qualquer resposta de rastreio invalida o print desta página.
      if (rastreio.vazaram.length) {
        vazamentos++
        falhas++
        console.log(`!! ${rotulo} RASTREIO RESPONDEU — print descartado: ${rastreio.vazaram.join(' | ')}`)
        continue
      }

      // Confere a head VISÍVEL neste aparelho contra o catálogo (só avisa,
      // não grava). Em cada aparelho, e não só no celular: o Elementor monta
      // blocos separados para desktop e celular, cada um com o seu h1, e o
      // escondido continua no HTML. Ler o primeiro h1 da página (como na
      // primeira versão) conferia o bloco de desktop mesmo no print de celular
      // — e deixou passar a LP01 inteira com a mesma headline no celular.
      // textContent e não innerText: innerText aplica o text-transform e
      // devolveria a headline em caixa alta.
      {
        const { result } = await cdp.enviar('Runtime.evaluate', {
          expression:
            "(() => { const vis = [...document.querySelectorAll('h1')].filter((h) => h.getClientRects().length > 0 && getComputedStyle(h).visibility !== 'hidden'); return vis.length ? vis[0].textContent : '' })()",
          returnByValue: true,
        })
        const publicada = normaliza(result?.value)
        const catalogo = normaliza(c.head)
        if (publicada && publicada !== catalogo) {
          // Mostra o trecho em volta da PRIMEIRA DIFERENÇA, não o começo do
          // texto: a diferença costuma ser um espaço ou uma pontuação no meio,
          // e um corte fixo no início escondia justamente ela (foi o que
          // aconteceu com o "renda,sem" da lp01-h3).
          let k = 0
          while (k < publicada.length && publicada[k] === catalogo[k]) k++
          const trecho = (s) => JSON.stringify(s.slice(Math.max(0, k - 30), k + 30))
          console.log(`   aviso: a head visível no ${ap.nome} difere do catálogo em ${base} (posição ${k})\n     página  : ${trecho(publicada)}\n     catálogo: ${trecho(catalogo)}`)
          // Diferença logo no começo é outra headline, não um detalhe: mostra inteira.
          if (k < 20) console.log(`     headline inteira no ${ap.nome}: ${JSON.stringify(publicada)}`)
        }
      }

      const { data } = await cdp.enviar('Page.captureScreenshot', { format: 'jpeg', quality: 82 })
      const buf = Buffer.from(data, 'base64')
      const kb = `${Math.round(buf.length / 1024)} KB`.padStart(7)
      const nota = `rastreio: ${rastreio.tentadas} tentativas, ${rastreio.bloqueadas} bloqueadas${noTempo ? '' : ' | load estourou 30s'}`

      if (LOCAL) {
        const arq = join(pastaLocal, `${base}-${ap.nome}.jpg`)
        writeFileSync(arq, buf)
        console.log(`ok ${rotulo} ${kb}  ${nota}\n   ${arq}`)
        continue
      }

      const destino = `paginas/${base}-${ap.nome}-${carimbo}.jpg`
      const subido = await subirNoStorage(destino, buf)
      if (subido.erro) {
        falhas++
        console.log(`!! ${rotulo} FALHA upload: ${subido.erro}`)
        continue
      }
      const publica = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${destino}`
      const { error: eUp } = await mkt.from('paginas_catalogo').update({ [ap.coluna]: publica }).eq('pagina', c.pagina)
      if (eUp) {
        falhas++
        console.log(`!! ${rotulo} subiu mas NÃO gravou: ${eUp.message}`)
        continue
      }
      console.log(`ok ${rotulo} ${kb}  ${nota}`)
    }
  }

  cdp.fechar()
} catch (e) {
  falhas++
  console.error('erro:', e.message)
} finally {
  chrome.kill()
  await dormir(800)
  try {
    rmSync(perfil, { recursive: true, force: true })
  } catch {
    /* o Windows às vezes segura o perfil por um instante; é pasta temporária */
  }
}

console.log(`\nresumo: ${falhas} falha(s)${vazamentos ? `, ${vazamentos} com rastreio que respondeu` : ', nenhum rastreio vazou'}`)
if (LOCAL) console.log(`arquivos em: ${pastaLocal}`)
process.exit(falhas ? 1 : 0)
