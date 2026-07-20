-- ============================================================================
-- TRANCA o schema mkt_wep: tira o acesso do anon/authenticated.
--
-- ⚠️ RODE SÓ DEPOIS que a API /api/dashboard estiver funcionando (senão o
--    painel para de carregar — ele passa a depender do "porteiro").
--
-- Depois disto, a anon key sozinha NÃO lê mais nada. Só a service_role
-- (usada exclusivamente pelo servidor, na /api/dashboard) tem acesso.
-- Nada disso afeta o app do Quartavia (mkt_wep é só nosso).
-- ============================================================================

revoke usage   on schema mkt_wep            from anon, authenticated;
revoke select  on all tables in schema mkt_wep    from anon, authenticated;
revoke execute on all functions in schema mkt_wep from anon, authenticated;

-- Impede que objetos criados no futuro voltem a ficar abertos.
alter default privileges in schema mkt_wep revoke select  on tables    from anon, authenticated;
alter default privileges in schema mkt_wep revoke execute on functions from anon, authenticated;

-- ----------------------------------------------------------------------------
-- Para REVERTER (caso precise voltar atrás durante testes):
--
--   grant usage   on schema mkt_wep            to anon, authenticated;
--   grant select  on all tables in schema mkt_wep    to anon, authenticated;
--   grant execute on all functions in schema mkt_wep to anon, authenticated;
-- ----------------------------------------------------------------------------
