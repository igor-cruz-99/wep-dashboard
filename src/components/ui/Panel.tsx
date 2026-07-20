import type { CSSProperties, ReactNode } from 'react'

interface PanelProps {
  children: ReactNode
  className?: string
  style?: CSSProperties
}

/** Cartão base do painel: fundo escuro, borda sutil, cantos arredondados. */
export function Panel({ children, className = '', style }: PanelProps) {
  return (
    <div
      className={`rounded-2xl border border-line bg-card ${className}`}
      style={style}
    >
      {children}
    </div>
  )
}

interface SectionTitleProps {
  overline?: string
  title: string
  className?: string
  /** Cor do título (classe Tailwind). Padrão: text-cream. */
  titleClassName?: string
}

/** Título de seção no padrão da referência: overline pequena + título serifado. */
export function SectionTitle({
  overline,
  title,
  className = '',
  titleClassName = 'text-cream font-bold',
}: SectionTitleProps) {
  return (
    <div className={className}>
      {overline && (
        <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-muted">
          {overline}
        </p>
      )}
      <h2 className={`font-sans text-xl ${titleClassName}`}>{title}</h2>
    </div>
  )
}
