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

/**
 * CAC SEAL: investimento ÷ TOTAL de vendas SEAL (completas + complementos).
 * Quem pagou só uma parte já é venda — só não é venda fechada; a separação
 * entre as duas está nos dois cards ao lado. Usa o mesmo denominador do card
 * "CAC SEAL" do topo, de propósito: dois números com o mesmo nome na mesma
 * tela confundiriam mais do que informariam.
 */
function CacCard({ investimento, vendasSeal }: { investimento: number; vendasSeal: number }) {
  const accent = '#c9945f'
  const cac = vendasSeal > 0 ? investimento / vendasSeal : null
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
      <p className="mt-1 text-xs text-muted">Investimento ÷ vendas SEAL</p>
      <p className="mt-3 text-sm text-cream">
        {formatBRL(investimento)} <span className="text-muted">÷ {formatInt(vendasSeal)}</span>
      </p>
      <p className="text-[11px] text-muted">completas + complementos</p>
    </Panel>
  )
}

/**
 * Bloco SEAL: cards de situação — quem pagou o SEAL inteiro, quem pagou só
 * uma parte, e o CAC SEAL. Agrupado por email, todas as origens.
 *
 * A situação vem do VALOR pago no período (>= R$ 3.000 é completa), não do
 * nome do produto: na origem tudo se chama "SEAL" hoje, então classificar
 * pelo texto marcava como quitado quem tinha pago R$ 500 (ver sql/77).
 *
 * `investimento` vem do funil (respeita o filtro de período ativo).
 */
export function SealCards({ seal, investimento }: { seal: SealResumo; investimento: number }) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <SealCard
        label="Completas"
        sub="Pagaram o SEAL inteiro (à vista ou somando pedidos)"
        data={seal.completa}
        accent="#9ed08b"
      />
      <SealCard
        label="Complemento"
        sub="Pagaram só uma parte (abaixo de R$ 3.000)"
        data={seal.complemento}
        accent="#e8b05c"
      />
      <CacCard
        investimento={investimento}
        vendasSeal={seal.completa.alunos + seal.complemento.alunos}
      />
    </div>
  )
}
