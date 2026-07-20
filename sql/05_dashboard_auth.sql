-- ============================================================================
-- Controle de acesso do dashboard — 100% isolado no schema mkt_wep.
-- NÃO toca em auth.users, triggers, nem em nada do app existente (Quartavia).
--
-- Ideia: o login é o Supabase Auth nativo (compartilhado), mas só entram no
-- painel os emails que estiverem nesta allowlist. Os milhares de usuários do
-- outro app continuam sem acesso ao dashboard.
-- ============================================================================

-- 1) Tabela de emails autorizados (só no nosso schema)
create table if not exists mkt_wep.dashboard_allowlist (
  email      text primary key,
  nome       text,
  criado_em  timestamptz default now()
);

-- RLS ligado e SEM policies: ninguém lê a lista direto pela API.
-- A checagem acontece só pela função security definer abaixo.
alter table mkt_wep.dashboard_allowlist enable row level security;

-- 2) Função que diz se o usuário logado está autorizado.
--    Lê o email do próprio JWT da sessão — não dá pra forjar pelo front.
create or replace function mkt_wep.fn_is_dashboard_user()
returns boolean
language sql
stable
security definer
set search_path = mkt_wep, public, pg_temp
as $$
  select exists (
    select 1 from mkt_wep.dashboard_allowlist
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function mkt_wep.fn_is_dashboard_user() from public;
grant execute on function mkt_wep.fn_is_dashboard_user() to authenticated;

-- 3) Autorize os emails do time (um insert por pessoa).
--    ⚠️ o email precisa ter uma conta no Supabase Auth para conseguir logar.
insert into mkt_wep.dashboard_allowlist (email, nome) values
  ('igorsousacruz99@gmail.com', 'Igor')
on conflict (email) do nothing;
