import type { SealResumo, SealSituacao } from '../../types'
import { formatBRL, formatInt } from '../../utils/format'
import { Panel } from '../ui/Panel'

interface CardProps {
  label: string
  sub: string
  data: SealSituacao
  /** Cor de destaque (glow + número). */
  accent: string
}

/** Card de situação SEAL: nº de alunos em destaque + valor somado embaixo. */
function SealCard({ label, sub, data, accent }: CardProps) {
  return (
    <Panel
      className="relative overflow-hidden px-5 pb-5 pt-4"
      style={{
        backgroundImage: `radial-gradient(120% 90% at 100% 0%, ${accent}2e 0%, transparent 55%)`,
      }}
    >
      <span className="text-[11px] font-semibold uppercase tracking-[0.15em] text-muted">
        {label}
      </span>
      <p className="mt-2 flex items-baseline gap-2">
        <span className="text-4xl font-bold tracking-tight" style={{ color: accent }}>
          {formatInt(data.alunos)}
        </span>
        <span className="text-sm text-muted">{data.alunos === 1 ? 'aluno' : 'alunos'}</span>
      </p>
      <p className="mt-1 text-xs text-muted">{sub}</p>
      <p className="mt-3 text-lg font-semibold text-cream">{formatBRL(data.valorTotal)}</p>
      <p className="text-[11px] text-muted">total pago</p>
    </Panel>
  )
}

/** Card do CAC SEAL: investimento ÷ vendas completas (quitadas). */
function CacCard({ investimento, vendasCompletas }: { investimento: number; vendasCompletas: number }) {
  const accent = '#c9945f'
  const cac = vendasCompletas > 0 ? investimento / vendasCompletas : null
  return (
    <Panel
      className="relative overflow-hidden px-5 pb-5 pt-4"
      style={{
        backgroundImage: `radial-gradient(120% 90% at 100% 0%, ${accent}2e 0%, transparent 55%)`,
      }}
    >
      <span className="text-[11px] font-semibold uppercase tracking-[0.15em] text-muted">
        CAC SEAL
      </span>
      <p className="mt-2 text-4xl font-bold tracking-tight" style={{ color: accent }}>
        {cac === null ? '—' : formatBRL(cac)}
      </p>
      <p className="mt-1 text-xs text-muted">Investimento ÷ vendas completas</p>
      <p className="mt-3 text-sm text-cream">
        {formatBRL(investimento)} <span className="text-muted">÷ {formatInt(vendasCompletas)}</span>
      </p>
      <p className="text-[11px] text-muted">investimento ÷ quitados</p>
    </Panel>
  )
}

/**
 * Bloco SEAL (roadmap item 2): cards de situação — quem quitou (pagou tudo),
 * quem pagou só a reserva, e o CAC SEAL. Agrupado por email, todas as origens.
 * `investimento` vem do funil (respeita o filtro de período ativo).
 */
export function SealCards({ seal, investimento }: { seal: SealResumo; investimento: number }) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <SealCard
        label="Quitaram"
        sub="Pagaram tudo (complemento ou à vista)"
        data={seal.quitou}
        accent="#9ed08b"
      />
      <SealCard
        label="Só reserva"
        sub="Pagaram só a taxa de entrada"
        data={seal.reserva}
        accent="#e8b05c"
      />
      <CacCard investimento={investimento} vendasCompletas={seal.quitou.alunos} />
    </div>
  )
}
