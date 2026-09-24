import { TAXA_META_ROTULO } from '../../lib/taxaMeta'
import type { Filters, Origem } from '../../types'

export type Preset = '7D' | 'Ontem' | 'Hoje'

interface HeaderProps {
  filters: Filters
  tags: string[]
  onChange: (patch: Partial<Filters>) => void
  /** Taxa cobrada sobre o investimento: liga/desliga o acréscimo nos custos. */
  taxaMeta?: boolean
  onToggleTaxaMeta?: () => void
  activePreset?: Preset | null
  onPreset?: (p: Preset) => void
  userEmail?: string
  onLogout?: () => void
  /** Sobretítulo (ex.: "Dashboard Meteórico"). */
  overline?: string
  /** Mostrar o dropdown de tag (na sidebar-first, fica oculto). */
  showTagFilter?: boolean
  /** Mostrar os checks de origem (só na etapa Meteórico). */
  showOrigem?: boolean
}

export function Header({
  filters,
  tags,
  onChange,
  taxaMeta = false,
  onToggleTaxaMeta,
  activePreset,
  onPreset,
  userEmail,
  onLogout,
  overline = 'Dashboard',
  showTagFilter = true,
  showOrigem = true,
}: HeaderProps) {
  // Recorte de origem via dois checks. 'todas' = os dois marcados.
  const paginaOn = filters.origem === 'todas' || filters.origem === 'pagina'
  const nativoOn = filters.origem === 'todas' || filters.origem === 'nativo'
  const toggleOrigem = (which: 'pagina' | 'nativo') => {
    const nextPagina = which === 'pagina' ? !paginaOn : paginaOn
    const nextNativo = which === 'nativo' ? !nativoOn : nativoOn
    // Nunca deixa os dois desmarcados (equivale a "não mostrar nada") → volta pra 'todas'.
    let origem: Origem = 'todas'
    if (nextPagina && !nextNativo) origem = 'pagina'
    else if (!nextPagina && nextNativo) origem = 'nativo'
    onChange({ origem })
  }

  return (
    <header className="flex items-center justify-between gap-4">
      <div className="flex min-w-0 items-center gap-3">
        <img src="/logo.png" alt="" className="h-12 w-auto shrink-0" />
        <div className="min-w-0">
          <p className="text-[10px] font-semibold uppercase tracking-[0.25em] text-muted">
            {overline}
          </p>
          <h1 className="truncate font-sans text-2xl font-bold text-[#c9b7a0]">
            Workshop Estrategista Patrimonial
          </h1>
        </div>
      </div>

      <div className="flex shrink-0 items-center gap-2">
        {/* Taxa Meta: acrescenta a taxa ao investimento e a tudo que deriva dele
            (CAC, CPL, CPM, CPC, CPLV). Ligado fica em dourado cheio, para dar
            para ver de longe que os números na tela não são o gasto puro. */}
        {onToggleTaxaMeta && (
          <button
            onClick={onToggleTaxaMeta}
            role="switch"
            aria-checked={taxaMeta}
            title={
              taxaMeta
                ? `Taxa Meta LIGADA: investimento e custos com +${TAXA_META_ROTULO}%`
                : `Taxa Meta desligada: investimento como vem da Meta, sem a taxa`
            }
            className={`flex h-10 shrink-0 items-center gap-2 rounded-xl border px-3 transition-colors ${
              taxaMeta
                ? 'border-gold bg-gold/20 text-cream'
                : 'border-line bg-card text-muted hover:border-gold/50 hover:text-cream'
            }`}
          >
            <span
              className={`relative h-4 w-7 shrink-0 rounded-full transition-colors ${
                taxaMeta ? 'bg-gold' : 'bg-line'
              }`}
              aria-hidden
            >
              <span
                className={`absolute top-0.5 h-3 w-3 rounded-full bg-card transition-all ${
                  taxaMeta ? 'left-3.5' : 'left-0.5'
                }`}
              />
            </span>
            <span className="text-xs font-semibold whitespace-nowrap">
              Taxa Meta
              <span className="ml-1 text-[10px] font-normal text-muted">
                +{TAXA_META_ROTULO}%
              </span>
            </span>
          </button>
        )}

        {/* Filtro de Tag (oculto na navegação por sidebar) */}
        {showTagFilter && (
        <label className="flex h-10 items-center gap-2 rounded-xl border border-line bg-card px-3.5">
          <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-muted">
            Filtro
          </span>
          <select
            value={filters.tag ?? tags[0]}
            onChange={(e) => onChange({ tag: e.target.value })}
            className="appearance-none bg-transparent pr-7 text-sm font-semibold text-cream outline-none"
            style={{
              backgroundImage:
                "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%23a3907a' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'><polyline points='6 9 12 15 18 9'/></svg>\")",
              backgroundRepeat: 'no-repeat',
              backgroundPosition: 'right 0.25rem center',
            }}
          >
            {tags.map((t) => (
              <option key={t} value={t} className="bg-card text-cream">
                {t}
              </option>
            ))}
          </select>
        </label>
        )}

        {/* Filtro de Origem (recorte da captação: páginas vs formulário nativo) */}
        {showOrigem && (
        <div className="flex h-10 items-center gap-1 rounded-xl border border-line bg-card px-2">
          <span className="px-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-muted">
            Origem
          </span>
          {([
            { key: 'pagina', label: 'Páginas', on: paginaOn },
            { key: 'nativo', label: 'Forms nativo', on: nativoOn },
          ] as const).map((o) => (
            <button
              key={o.key}
              onClick={() => toggleOrigem(o.key)}
              aria-pressed={o.on}
              className={`flex items-center gap-1.5 rounded-lg px-2 py-1.5 text-xs font-semibold transition-colors ${
                o.on ? 'text-cream' : 'text-muted/60 hover:text-muted'
              }`}
            >
              <span
                className={`flex h-3.5 w-3.5 items-center justify-center rounded border ${
                  o.on ? 'border-gold bg-gold text-[#191210]' : 'border-line bg-card-2'
                }`}
                aria-hidden
              >
                {o.on && (
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M20 6 9 17l-5-5" />
                  </svg>
                )}
              </span>
              {o.label}
            </button>
          ))}
        </div>
        )}

        {/* Atalhos de período: 7D / Ontem / Hoje (toggle) */}
        {onPreset && (
          <div className="flex h-10 items-center gap-1 rounded-xl border border-line bg-card p-1">
            {(['7D', 'Ontem', 'Hoje'] as Preset[]).map((pr) => (
              <button
                key={pr}
                onClick={() => onPreset(pr)}
                className={`rounded-lg px-2.5 py-1.5 text-xs font-bold transition-colors ${
                  activePreset === pr
                    ? 'bg-gold text-[#191210]'
                    : 'text-muted hover:text-cream'
                }`}
              >
                {pr}
              </button>
            ))}
          </div>
        )}

        {/* Filtro de período */}
        <div className="flex items-center gap-2 rounded-xl border border-line bg-card px-3.5 py-1.5">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden>
            <rect x="3" y="5" width="18" height="16" rx="2" stroke="#e8b05c" strokeWidth="1.8" />
            <path d="M3 9h18M8 3v4M16 3v4" stroke="#e8b05c" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
          <div>
            <p className="text-center text-[10px] font-semibold uppercase tracking-[0.2em] text-muted">
              Período
            </p>
            <div className="mt-0.5 flex items-center gap-1.5 text-xs font-semibold text-cream">
              <input
                type="date"
                value={filters.from}
                onChange={(e) => onChange({ from: e.target.value })}
                className="bg-transparent outline-none"
              />
              <span className="text-muted">→</span>
              <input
                type="date"
                value={filters.to}
                onChange={(e) => onChange({ to: e.target.value })}
                className="bg-transparent outline-none"
              />
            </div>
          </div>
        </div>

        {/* Conta / logout */}
        {onLogout && (
          <div className="flex h-10 items-center gap-2 rounded-xl border border-line bg-card px-3.5">
            {userEmail && (
              <span className="hidden max-w-[150px] truncate text-xs text-muted lg:block" title={userEmail}>
                {userEmail}
              </span>
            )}
            <button
              onClick={onLogout}
              title="Sair"
              className="flex items-center gap-1.5 text-xs font-semibold text-muted hover:text-cream"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden>
                <path
                  d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l-5-5 5-5M5 12h11"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
              Sair
            </button>
          </div>
        )}
      </div>
    </header>
  )
}
