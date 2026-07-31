/** Visões do painel (etapas do lançamento). */
export type View = 'meteorico' | 'padrao' | 'seal'

interface PhaseDef {
  id: View
  label: string
  icon: React.ReactNode
  hasTags: boolean
}

// Ícones simples (herdam a cor via currentColor).
const IconMeteorico = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
    <path d="M13 2 3 14h7l-1 8 10-12h-7z" />
  </svg>
)
const IconPadrao = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
    <circle cx="12" cy="12" r="8" />
    <circle cx="12" cy="12" r="3.2" />
  </svg>
)
const IconSeal = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round">
    <path d="M12 3 3 9l9 12 9-12-9-6z" />
    <path d="M3 9h18M12 3v18" strokeWidth="1.2" />
  </svg>
)

const PHASES: PhaseDef[] = [
  { id: 'meteorico', label: 'WEP – Meteórico', icon: IconMeteorico, hasTags: true },
  { id: 'padrao', label: 'WEP – Padrão', icon: IconPadrao, hasTags: true },
  { id: 'seal', label: 'SEAL – geral', icon: IconSeal, hasTags: false },
]

interface SidebarProps {
  view: View
  activeTag: string | null
  tags: string[] // nomes das tags (sem "Todas")
  collapsed: boolean
  onToggle: () => void
  onSelectView: (v: View) => void
  onSelectTag: (v: View, tag: string) => void
}

export function Sidebar({
  view,
  activeTag,
  tags,
  collapsed,
  onToggle,
  onSelectView,
  onSelectTag,
}: SidebarProps) {
  return (
    <aside
      className={`sticky top-0 flex h-screen shrink-0 flex-col border-r border-line bg-card-2 transition-[width] duration-200 ${
        collapsed ? 'w-14' : 'w-56'
      }`}
    >
      {/* Seta expandir/reduzir */}
      <div className={`flex h-14 items-center border-b border-line ${collapsed ? 'justify-center' : 'justify-end px-2'}`}>
        <button
          onClick={onToggle}
          title={collapsed ? 'Expandir' : 'Reduzir'}
          aria-label={collapsed ? 'Expandir menu' : 'Reduzir menu'}
          className="flex h-8 w-8 items-center justify-center rounded-lg text-muted transition-colors hover:bg-card hover:text-cream"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
            className={`transition-transform ${collapsed ? '' : 'rotate-180'}`}>
            <path d="m9 6 6 6-6 6" />
          </svg>
        </button>
      </div>

      <nav className="flex-1 overflow-y-auto py-2">
        {PHASES.map((p) => {
          const active = view === p.id
          return (
            <div key={p.id} className="px-2">
              <button
                onClick={() => onSelectView(p.id)}
                title={collapsed ? p.label : undefined}
                className={`mt-1 flex w-full items-center gap-3 rounded-lg px-2.5 py-2 text-left text-sm font-semibold transition-colors ${
                  active ? 'bg-gold/15 text-gold' : 'text-muted hover:bg-card hover:text-cream'
                } ${collapsed ? 'justify-center' : ''}`}
              >
                <span className="shrink-0">{p.icon}</span>
                {!collapsed && <span className="truncate">{p.label}</span>}
              </button>

              {/* Sub-itens: tags da etapa */}
              {!collapsed && p.hasTags && active && (
                <div className="mb-1 ml-4 mt-0.5 flex flex-col border-l border-line pl-2">
                  {tags.map((t) => {
                    const on = activeTag === t
                    return (
                      <button
                        key={t}
                        onClick={() => onSelectTag(p.id, t)}
                        className={`rounded px-2 py-1 text-left text-xs transition-colors ${
                          on ? 'text-gold' : 'text-muted hover:text-cream'
                        }`}
                      >
                        {t}
                      </button>
                    )
                  })}
                </div>
              )}
            </div>
          )
        })}
      </nav>
    </aside>
  )
}
