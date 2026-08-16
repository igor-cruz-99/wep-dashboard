-- 55_criativos_drive.sql  (VERSÃO 2 — substitui a anterior, que nunca foi rodada)
-- ============================================================================
-- MÍDIA DO POPUP DE PREVIEW VINDA DO DRIVE, pelo link direto da planilha.
--
-- O que mudou da versão 1: antes o n8n teria que procurar o arquivo pelo NOME
-- dentro de 22 pastas do Drive (passo frágil). Agora a planilha entrega o link
-- de cada arquivo, então guardamos o fileId do Drive e o n8n baixa direto.
--
-- Fonte: planilha "Controle de Criativos" (SEAL AGO26), aba "Captura de Leads",
-- coluna B (nome do anúncio) + colunas K (feed) e L (story). Os links estavam
-- como hyperlink de célula — o export CSV os descarta, o .xlsx os preserva.
--
-- Por que casar por NOME e não por ad_id: o mesmo criativo é subido em várias
-- campanhas, cada uma com seu ad_id. Casando por nome, um download cobre todas
-- as veiculações — 67 criativos da planilha estão em campanha WEP e cobrem
-- 156 ad_ids.
--
-- Por que a Meta não serve: devolve thumbnail de 64x64 (borrado) e o ramo de
-- vídeo do sync nunca funcionou (bucket com 276 .jpg e ZERO .mp4).
--
-- O "tipo" vem do padrão do próprio nome (_img_ / _vid_ / _car_), que está
-- preenchido em 100% dos criativos — a coluna "Tipo do Conteúdo" da planilha
-- está vazia nas linhas novas.
-- ============================================================================

drop table if exists mkt_wep.criativos_drive;
create table mkt_wep.criativos_drive (
  ad_name           text primary key,  -- = dim_anuncios.anuncio
  tipo              text,              -- imagem | video | carrossel
  drive_feed_id     text,              -- fileId do criativo em formato feed
  drive_story_id    text,              -- fileId da versão stories (fallback)
  storage_url       text,              -- imagem/capa já re-hospedada
  storage_video_url text,              -- vídeo já re-hospedado
  synced_at         timestamptz,       -- null = na fila do n8n
  erro              text               -- motivo da última falha
);

comment on table mkt_wep.criativos_drive is
  'Midia dos criativos vinda do Drive (link da planilha de controle), casada por NOME do anuncio. Tem precedencia sobre core.ads_thumbnails (Meta) na fn_ad_thumbnail.';

insert into mkt_wep.criativos_drive (ad_name, tipo, drive_feed_id, drive_story_id)
values
  ('seal_ad_0001_vj_img_meteor_ticket', 'imagem', '1u_3DAgsR1FGKRsD4VNGiYdvc08SSNVVi', '1UwiJkLv8-UJREDFxWj4q1wGWl7XPyl-W'),
  ('seal_ad_0002_vj_img_meteor_banner_sem_preço', 'imagem', '1RImFVQ3Xp0prymJhMv2TvZFOKGRuZAsp', '1Vy64oS1n3gMihptYcnePhr_exSj5ontS'),
  ('seal_ad_0003_vj_img_meteor_nova_fonte_de_renda', 'imagem', '1xrkBvTtjGXWWzNDtd-ice8o__rnOBuHn', '1DT1QutoWCAG8kwdcRDRPEbkc6SiHmEip'),
  ('seal_ad_0004_vj_img_meteor_2_dias_para_construir', 'imagem', '1rh3XnpXX9ktW9lTGqQY5qoZ0LvM8dAem', '1-qqtcs0rw2rpTRdfmSSLYul45vm4v3y1'),
  ('seal_ad_0005_vj_img_meteor_seja_remunerado', 'imagem', '1IhKVhJwnawnxwBVf_Gqudn6PXVIZVfHb', '14TFmHm9Pk3h78C2iCLPpDce3S5uddMvy'),
  ('seal_ad_0006_vj_img_meteor_proximo_workshop', 'imagem', '1TUdh6e0Lg20FzmJN7seHVtAGfQah06eQ', '1PyZCS40ZDz5eg0t4j_YGvx02WxOz2eiA'),
  ('seal_ad_0007_vj_img_meteor_lote_zero', 'imagem', '1zYuUtpgo_mkLIGHSY7dQJ0cvACN1dcmQ', '1I5Vx1twzozy6Kts6XMtoM25OqKuiwNKw'),
  ('seal_ad_0008_vj_img_meteor_menos_de_27_reais', 'imagem', '1yT2scDod8-TIB7-WAvXR5aavkrWD6Rcu', '1h1K0dHC5CFsriGBU2wsNT7KNkRtcany6'),
  ('seal_ad_0009_vj_vid_meteor_ganhar_dinheiro_mercad_financeiro', 'video', '1fQXGynNJj6DZvSFffaKSTEO8yF7KJdwX', '1GhVCNdkIrHzFp3lfbGRy3Jv5OWhBFC6E'),
  ('seal_ad_0010_vj_vid_meteor_vou_te_contar_uma_coisa', 'video', '11E46ckBEDGrI3EDQrVWFPwHsBBx08D5s', '1JrHVrc6t5iU2JzWuguAaoHREyjnDoZJe'),
  ('seal_ad_0011_vj_vid_meteor_banco_quebrando', 'video', '1ZgnYxbUFst7E5VsBheBByhDqXZK_V0BB', '1u2sNuEf8vgoMiGtw9D3MDZE3dKKURalC'),
  ('seal_ad_0012_vj_vid_meteor_alguem_da_sua_rede', 'video', '13uZh4lXNbEBNgQ-e8dPyXSBJtCksnztp', '1Vz5Z-8qgWXTpmbAhn2NoHYwr1AwMu1Ye'),
  ('seal_ad_0013_vj_vid_meteor_banco_quebrando_slides', 'video', null, null),
  ('seal_ad_0014_vj_vid_meteor_ultimo_dia_01', 'video', '1ZVt_hP6BkBiIjXcrm9ieh45YcT98Fguc', '1l7dAPXng3eeMjLsJdUn93jP3E0XvrrQ4'),
  ('seal_ad_0015_vj_vid_meteor_ultimo_dia_02', 'video', '1dYqgJ0_KqRX5zHc7bp6G3sV0APGM0Rpl', '1qh9wPGA8FRX6ZTCDLHdZhH5RcpaUE1Dy'),
  ('seal_ad_0016_vj_vid_meteor_ultimo_dia_03', 'video', '1w-L-is56LEFZ_7UgSLN5GRqUnfwCcsbI', '1dxrHpYeRb4-HkO07FFe-AANavGDxkLmT'),
  ('seal_ad_0017_vj_vid_meteor_ultimo_dia_04', 'video', '14j62k5ugcOtbFFXjjJrjUQiM_wCVzUwA', '13ckv9lsJo36kENc7gihq4G0fD5xlARi_'),
  ('seal_ad_0018_vj_vid_meteor_ultimo_dia_05', 'video', '1uQETg9Fl7VaZKYSePWy5pV9K2a3TDSoi', '1UGw-DCP_lCvYjFJ-3pur90UyBIEISocf'),
  ('seal_ad_0019_vj_vid_meteor_ultimo_dia_06', 'video', '1yPi5CraYk1_Yw4HZOQVMILw76OETN3i2', '12uKPVxs7O1tFy7WdjDvyRy6Q4pNOH-o_'),
  ('seal_ad_0020_vj_vid_meteor_rmkt_tempo_acabando', 'video', '17DmfsxRn7Gh3jIqs5IXmb44BAty2tISQ', null),
  ('seal_ad_0021_vj_img_meteor_rmkt_falta_so_1_passo', 'imagem', '1--x8Gc37_F3rvRwChNdyD2k2Ju8T_XCR', '1eNzVKt1cpz6Eirx5CJ2gMk34zcP7bJaf'),
  ('seal_ad_0022_vj_vid_ganhar_dinheiro_mercado_financeiro', 'video', '1D0Izoq8kglcZGWeAGLAu2zuO9v-JvD1R', '1uI3xKjtTNa7kHmuE6it3QxIHrsBO08Dy'),
  ('seal_ad_0023_vj_vid_vou_te_contar_uma_coisa', 'video', '1EGcmxrIcOkMrKBkOjsGbIM0wbuQaVlmg', '19I0SWD2jtZPEmhZ-jTXg5dJpVteyhJ7R'),
  ('seal_ad_0024_vj_vid_banco_quebrando_venda_direta', 'video', '1NoQScxAs_vvhIEHGpKQx-h3Nvao6MMG2', '1zd_eoDQlgefglvlM7ktoHRp6H8W8bMf1'),
  ('seal_ad_0025_vj_vid_alguem_da_sua_rede_de_confianca', 'video', '1UYlMnsiNEHQAqNObeUhsZMz6ipDgJD2B', '1VAeq7vH2840ZwksexdTbzheoMV06vcWn'),
  ('seal_ad_0026_vj_vid_me_responde_uma_coisa', 'video', '1LEtGi5aMzuaGXBJYeufKU0wzTCAGm2py', '1OdezReh4sccO8hJI-x_OLUj9WkGsVIzX'),
  ('seal_ad_0027_vj_vid_imagina_uma_familia', 'video', '1ALcD_ETxiIVEig0YDlhPzUM-j_F9shtS', '1yUCZnDyY3JRKggVIpFyRKLBTxCeQhqt0'),
  ('seal_ad_0028_vj_vid_vc_pode_se_tornar_estrategista_patrimonial', 'video', '1GxJY9kqsePtH2qJv5cAJgnEcvSkwHTF-', '1ftGkUX_-WYcTku-_78ONgl-8LQwH6DaI'),
  ('seal_ad_0029_vj_vid_renda_extra_rouba_seu_tempo_livre', 'video', '1oDbzpsnk2JYETWHEKbKMgqCXaBb5_kpj', '1OCkXuGwn-Yr7ljHIlUeqrDxQCeau2SFp'),
  ('seal_ad_0030_vj_vid_procurando_profissionais', 'video', '12Sx1BIz2mLUmpsxDz9DK5-w0wXfQqT7Z', '1vWJsT8bDpEAqLRQpErCzJ_JAwH3tAlPT'),
  ('seal_ad_0031_vj_vid_governo_aprovou_taxação_dividendos', 'video', '1yh8dqHWzkwlVH7LSS6zR2BUt0yy6JP6A', '1Wd1Iy7BJJaZPOfxHwK3uQNoR8x2cUosf'),
  ('seal_ad_0032_vj_vid_modelo_estrategista_patrimonial', 'video', '1mp5BzeDAeufav3jOzt_Z49I5dNkPPlzL', '1H2fSeRLdV_Uu9gP8tVFIG9ZvR5IJSvxA'),
  ('seal_ad_0033_vj_vid_todo_mes_que_passa', 'video', '1CpuMsX6glhxyM1k4AHpV7ewQUdL7ZhuS', '1UBLaGinQV6ASSa2vMu0GXKTz_9ThjbCI'),
  ('seal_ad_0034_vj_vid_existe_uma_profissão_no_brasil', 'video', '1Az7-X7nzX2AnF_-Wk9awZCURbbl4yFyf', '14RwSedZcGShp-Sr1WOav_Gf5CGe4Zodx'),
  ('seal_ad_0035_vj_vid_matematica_renda_recorrente', 'video', '1wArBrDegx7EOBg2qAF9hmy-q6gMYgdN1', '1lGWt1rHfjwQm9rc9wsoxktu_JEOTjWqh'),
  ('seal_ad_0036_vj_vid_existem_dois_tipos_de_profissional', 'video', '1SzkOCPx4NgqnEaYCTFwEAha25-ZrOxb5', '1ZhubNRfxgA58_4L9Y_yzKxxKyGGKPKi5'),
  ('seal_ad_0037_vj_car_profissoes', 'carrossel', null, null),
  ('seal_ad_0038_vj_img_ticket', 'imagem', '1Imp6z7w6Cv-MhqwPdu3LL5lnJad_Myr2', '1Q2kCGoT8Hbp0gxy-w0auzKUFp4KvM8tE'),
  ('seal_ad_0039_vj_img_workshop_intensivo', 'imagem', '1HQombVB_SQ0Hrmsub61l4-kCzPSlrE8Y', '1pyuPUfqf-69hdKWoiy7IWyeJg2W6EoO_'),
  ('seal_ad_0040_vj_img_nova_fonte_de_renda', 'imagem', '1UzAnoaaXmDEFB1cuLty26nqVb-CgH0uc', null),
  ('seal_ad_0041_vj_img_garanta_antes_da_virada_de_lote', 'imagem', '1S5H4i4NZIJgtCBUjZpSQcUKlsSB0oLaa', '1CxjXc292efDYcqSC6uESi2dbjQxOtr9N'),
  ('seal_ad_0042_vj_img_workshop_estrategista_patrimonial', 'imagem', '1n8at0mpfE-P8cmKOjoNtUJOYfY2MCtir', '1WaBt1dAvM5zcgom983JNWAGbHYvQEoGz'),
  ('seal_ad_0043_vj_car_procura-se', 'carrossel', null, null),
  ('seal_ad_0044_vj_car_governo_mudou', 'carrossel', null, null),
  ('seal_ad_0045_vj_car_nova_profissão', 'carrossel', null, null),
  ('seal_ad_0046_vj_car_banco_quebrando', 'carrossel', null, null),
  ('seal_ad_0047_vj_img_novahead_milhoes_de_familias', 'imagem', '1e9WZP68hqSbH1_Ar6Pwhly8G0konmPpv', '1_a4n2ufdwIuljD9c6Y2-k75TzlcZzjHq'),
  ('seal_ad_0048_vj_img_novahead_familias_alta_renda', 'imagem', '1iZ77HqABEjkCXYtLb5eEGna1Sx7zl72z', '1D2DRrjS1vb_uNodCYHjttgWb_LewFurE'),
  ('seal_ad_0049_vj_img_novahead_voce_sabia', 'imagem', '1lbwDKTMME5Croc6X3rChneETpevRsd20', '1r8RXtQLzu__K_o_xCJcCVH_PVrLpCiuD'),
  ('seal_ad_0050_vj_img_novahead_alguem_ja_te_procurou', 'imagem', '1bbTPCe01QZD52SM0JnpiZlimI1Y-GRDa', '1fNdXzcTeacpwKpz_68x_0GQeh9Zkwmmf'),
  ('seal_ad_051_vj_vid_ganhar_dinheiro_mercado_financeiro', 'video', '1JVWNQ5sa2pQvV_jS7Y7Qpfb4CQ6qpJOC', '1ciUPnCo1H5r8sxh8huNhf5-zA9lgN_DM'),
  ('seal_ad_052_vj_vid_me_responde_uma_coisa', 'video', '1q0BdYEf7xp3Jp-StsaQzfxdpBZ6uDH5g', '1EA0srHqYZOXTGxgq8ZBxq15uJwcwZH7T'),
  ('seal_ad_053_vj_vid_procurando_profissionais', 'video', '1eUIHD4L44_PPUa-dKe3_czEGsmzZyQQM', '1vMxlQ_aZD_8rcnwvqo_eITKK9T7U1CtP'),
  ('seal_ad_054_vj_car_estou_procurando_escuro', 'carrossel', null, null),
  ('seal_ad_055_vj_car_estou_procurando_claro', 'carrossel', null, null),
  ('seal_ad_056_vj_car_o_governo_aprovou_a_taxação_escuro', 'carrossel', null, null),
  ('seal_ad_057_vj_car_o_governo_aprovou_a_taxação_claro', 'carrossel', null, null),
  ('seal_ad_058_vj_vid_nova_narrativa_modelo_de_negocio', 'video', '1qUsM_mDN170zmBGK7QTVp6XsSgqHsfIB', '13MPq4cF0M2-M1mDgoe0L5pkj78k2S1LS'),
  ('seal_ad_059_vj_vid_nova_narrativa_maioria_dos_negocios_no_brasil', 'video', '1i2WS0oqNVaybavT8P_p1uKN46lqx1gM-', '1szSFxeGWpmYvraS5VIIQ5YjruvpKqU--'),
  ('seal_ad_060_vj_vid_nova_narrativa_renda_extra_recorrente', 'video', '1VhKyjCgQ5e6_UpyyPKSTkX9DinGTDctc', '1Q3bVJJdxzKvY-7sLxpIIIabLdfq9l4qR'),
  ('seal_ad_061_vj_vid_nova_narrativa_franquia_tradicional', 'video', '1dILOdT0EwCHpVv7deU_QjxbMNVkPT9gZ', '10eHdRkhyPYV-ihWLcjhqThG10Z4pRBXF'),
  ('seal_ad_062_vj_vid_nova_narrativa_franquia_comum', 'video', '16d0rhDNuOSsCEA6aXzO0aIIX7qtpJsUo', '1_mA7Ygnho5J7n6yAE0yugemExt-rR0dX'),
  ('seal_ad_063_vj_vid_nova_narrativa_faturar_mais', 'video', '1oAdidfL2YwehOosAt6sVehB6Uva8JNDJ', '166qebw84iu5hgeNlPrhNzth8D100VF_R'),
  ('seal_ad_064_vj_vid_nova_narrativa_contar_um_segredo', 'video', '1OLc2sXqBgMnsHXEgqPMJVun1GQt3PsDI', '1LId1Z5RMgDlOR-2CSb9fZ_ZBKx1PghRj'),
  ('seal_ad_065_vj_vid_nova_narrativa_quanto_te_custa', 'video', '1fIoa-1LT-u0VDeEK1w-D2GjxRxzDD7-9', '1VY5DRzI8CiCS02UoZX13apaOYoj-iTet'),
  ('seal_ad_066_vj_img_nova_narrativa_dono_de_microfranquia', 'imagem', '1N-7yLiSMnecXHbpRqCdtwgmO-W5jNSKs', '1LQOIFgEzz40BtwNCsOj4njXIq1JhzmT1'),
  ('seal_ad_067_vj_img_nova_narrativa_modelo_de_negocio_amarelo', 'imagem', '17flzdIUcRRIxkNlXisMeL-cYO3-WbpyE', '1x4P5ghKACl_WPj67EBg97Zp4OITfOXrF'),
  ('seal_ad_068_vj_img_nova_narrativa_modelo_de_negocio_vermelho', 'imagem', '1O4A1pcfd0_Hssl-4J_atDICPwxd9DWEq', '1PEAy-A0sqOyh93v9BxHg7U_gkg6-KDeE'),
  ('seal_ad_069_vj_img_nova_narrativa_adicionar_20mil', 'imagem', '17xglAkDEz_I1ClB7h71D46Zn5SQ2KDwL', '1Uf0wzqYOFX0KgpV7Q86OAUNa-Jepmt9s'),
  ('seal_ad_070_vj_img_nova_narrativa_micro_franquia_patrimonial', 'imagem', '1WwGu0rwiirZ-sJbRGfT8yyjJ9oO_A8ej', '1uPQMNVcZ5NAtMGm0eXTf5hHZdP3Rpc2P'),
  ('seal_ad_071_vj_img_funil_quiz_bussola_teste', 'imagem', '1WifT_hO_sjIGpC4Qx5BLG5-DhFH6Q67n', '1Ct-CUjNNXdvqvkSR0SizYIU2UDT-KzBP'),
  ('seal_ad_072_vj_img_funil_quiz_familiares_amigos_te_procuram_teste', 'imagem', '1LdbBOkMAl4ujEtle01OxEW89N_XJ8lWr', '14fSvcPi9YRHMaeC058qCOsAbdKFbfXnf'),
  ('seal_ad_073_vj_img_funil_quiz_segunda_fonte_renda_teste', 'imagem', '1EtjHZx7bK6IsxtvLptEvPsq9_3IyehZp', '1cRigTHiLHuw5nCH4MHWGviIKdDkdfJkG'),
  ('seal_ad_074_vj_img_funil_quiz_ajudar_familias_teste', 'imagem', '15Ierk36NmRAT0fJCDUjF-f3cPr2Were_', '1Ni57jJK7X41aUeDpZBTogJRx8iK31YBk'),
  ('seal_ad_075_vj_car_nova_narrativa_franquia_tradicional', 'carrossel', null, null),
  ('seal_ad_076_vj_car_nova_narrativa_maioria_dos_negocios', 'carrossel', null, null),
  ('seal_ad_077_vj_car_nova_narrativa_negocio_enxuto', 'carrossel', null, null),
  ('seal_ad_078_vj_vid_nova_narrativa_franquia_tradicional_variação', 'video', '1qtL5uLGwwP6re7p6Bwega9haLQBvlJPh', '1XrZ8JvhmdrlUtN-599926KWB9zqtmyBl'),
  ('seal_ad_079_vj_vid_nova_narrativa_faturar_mais_variação', 'video', '1-Y0g1nbId39ZwSQavSGlMICNSYT9No39', '1BSl2PFWpeNq3Gov_PaPnCVeU2ajxLcks'),
  ('seal_ad_080_vj_car_governo_microfranquia_V1', 'carrossel', null, null),
  ('seal_ad_081_vj_car_negocio_baixo_risco_escuro', 'carrossel', null, null),
  ('seal_ad_082_vj_img_ajudando_familias_alta_renda', 'imagem', '1O7CuLHnBz50GJEkU3aJGckhmSVE0pA1n', '1ZSXpi7iJGqxuDF4hiPvtglAgGcivHp7a'),
  ('seal_ad_083_vj_img_sem_trabalhar_mais_horas', 'imagem', '1hFc-NmMZ6H1g4FeunFXfXOt1Vy3ZEnzs', '1gNENMMSkZ36MzKipFJ-V8qggl4H4vUIW'),
  ('seal_ad_084_vj_img_sem_trabalhar_mais_horas_quartavia', 'imagem', '1SzrUEjrqP_vySJ6tdhEXIFXEtIKmhpx8', '1ow44u4lWAdk8G-7VZm_Lu6DbSY_tIGX6'),
  ('seal_ad_085_vj_vid_oleo_de_baleia_cta_workshop', 'video', null, '1Apic42jWfDLL0v5nlwZuYcZJ3CnBf0Mv'),
  ('seal_ad_086_vj_vid_energia_cta_workshop', 'video', null, '1uk7IOsncWvCxP0IumRtRsbr8uYznHBg-'),
  ('seal_ad_087_lz_vid_melhor_ad_modelo_de_negócio', 'video', null, '1bL10_-WbPcoF9x-CzyHA2rVe3WLl5uBo'),
  ('seal_ad_088_lz_vid_melhor_ad_micro_franquia', 'video', null, '1xnarEZhPIUmrGtaRR6p_POE7cW6M30u0'),
  ('seal_ad_089_lz_vid_governo_micro_franquia', 'video', null, '1erEIRO8ZY9toA_F4jtdNnyLMpI6cGOhs'),
  ('seal_ad_090_vj_vid_roma_cta_workshop', 'video', null, '1LcAsRTaL3F0XTu62YKZE6guUBYuZmbqw'),
  ('seal_ad_091_vj_vid_oportunidade_cta_workshop', 'video', null, '1Onz3u9zYncsBRs-zRpH31IjajaiIFcjn'),
  ('seal_ad_092_vj_vid_macaco_cta_workshop', 'video', null, '1VvB3IqhP-iUcKKbOK5qC6Ok-kbewJtiA'),
  ('seal_ad_93_vj_vid_abrir_um_negocio_serio_cta_saiba_mais.mp4', 'video', '14-qiGuNxUeGXdHqiofZFr0UZM_lqyzPU', '1pcU1WpCo4FOSGgX1v2Bx751DWRWLh6AP'),
  ('seal_ad_94_vj_vid_construir_um_negocio_cta_saiba_mais.mp4', 'video', '1SKHHzO-s6ApEhpMvGlMzJBmR43KpK1BE', '1pVr1tL8W612aj7lD-vhT6VYcdNRFCnHq'),
  ('seal_ad_95_vj_vid_maioria_dos_negócios__cta_saiba_mais.mp4', 'video', '1I2Af6muntdx0dN-GsGoTaw7nSaJV7rjl', '19m58S3g9VlNwvejv9EkiuSzmMr1jKIJF'),
  ('seal_ad_96_vj_vid_modelo_de_trabalho_cta_saiba_mais.mp4', 'video', '1wzjuUoGWzRnGctYd53ayDE3v1Cbv4sa3', '1mvNuQ04tKZYj9ixoZYq7XuV4-lj015Zc'),
  ('seal_ad_97_vj_vid_nao_precisa_escolher_entre_cta_saiba_mais.mp4', 'video', '1YyDtPR9PeUwQVbSMUVbzxLR4-6xYIpXN', '1AJWMCIdfLjRwXUZDZqFOeyYI8WMoJjOQ'),
  ('seal_ad_98_vj_vid_numa_franquia_comum_cta_saiba_mais.mp4', 'video', '1irdnYIYLApnaLNRnyJqYxnLzdEtlTI-T', '1ooYPXwt3GPZTdFbazAk4MHQjCNgeLPy1'),
  ('seal_ad_99_vj_vid_o_governo_aprovou_cta_saiba_mais.mp4', 'video', '1HVdfoYxQuyjyXH5GXyMvMz9MtB9RPQkj', '1KVL0wEH0xoE50fXLa2mDouSBEYK4UaUx'),
  ('seal_ad_100_vj_vid_se_vc_é_cta_saiba_mais.mp4', 'video', '1DXnezHeLQ_KR0OgY6IslZmsVtcW1ag-o', '1AJkTi60SLTIycCOvL3WqK3PyR5zsObue'),
  ('seal_ad_101_vj_vid_todo_negocio_de_sucesso_cta_saiba_mais.mp4', 'video', '1k5D0WZ7GDKx0_clB0jweGut8-90aJhiM', '1HEQQjydIDSTQqqtvHUQMCbQMBo9XNYaX'),
  ('seal_ad_102_vj_vid_vc_ja_sabe_o_valor_cta_saiba_mais.mp4', 'video', '1WYglkQbbjmu0Gt1BQNNU1QFwlSc7MhB9', '1xvnvIeW_ntBkFi4psUkPbjh-cIutpt2a');

-- ── Fila do n8n ─────────────────────────────────────────────────────────────
-- Só criativos que (a) têm arquivo no Drive e (b) foram veiculados em campanha
-- WEP — não adianta baixar mídia de anúncio que nunca subiu.
drop function if exists mkt_wep.fn_criativos_drive_pendentes(int);
create function mkt_wep.fn_criativos_drive_pendentes(p_limit int default 10)
returns table (
  ad_name       text,
  tipo          text,
  drive_file_id text
)
language sql
stable
as $$
  select c.ad_name, c.tipo, coalesce(c.drive_feed_id, c.drive_story_id)
    from mkt_wep.criativos_drive c
   where c.synced_at is null
     and coalesce(c.drive_feed_id, c.drive_story_id) is not null
     and exists (
       select 1 from mkt_wep.dim_anuncios d
        where lower(d.anuncio) = lower(c.ad_name)
          and d.campanha ilike '%wep%'
     )
   order by c.ad_name
   limit p_limit;
$$;

-- ── fn_ad_thumbnail: Drive primeiro, Meta como fallback ────────────────────
-- Contrato de retorno inalterado — o front não precisa mudar.
drop function if exists mkt_wep.fn_ad_thumbnail(text);
create function mkt_wep.fn_ad_thumbnail(p_ad_id text)
returns table (
  ad_id        text,
  ad_name      text,
  url          text,
  video_url    text,
  sincronizado boolean
)
language sql
stable
as $$
  select
    d.ad_id::text,
    d.anuncio::text,
    coalesce(c.storage_url, t.storage_url, t.image_url, t.thumbnail_url)::text,
    coalesce(c.storage_video_url, t.storage_video_url)::text,
    (c.synced_at is not null or t.synced_at is not null)
  from mkt_wep.dim_anuncios d
  left join mkt_wep.criativos_drive c
    on lower(c.ad_name) = lower(d.anuncio)
  left join core.ads_thumbnails t
    on t.ad_id::text = d.ad_id::text
  where d.ad_id::text = p_ad_id
  limit 1;
$$;

-- ── Conferências ────────────────────────────────────────────────────────────
-- (a) Seed carregado (esperado: 102 linhas — 58 video, 30 imagem, 14 carrossel):
select tipo, count(*) from mkt_wep.criativos_drive group by tipo order by tipo;

-- (b) Criativos veiculados em campanha WEP (esperado: 67):
select count(*) as veiculados from mkt_wep.criativos_drive c
 where exists (select 1 from mkt_wep.dim_anuncios d
                where lower(d.anuncio) = lower(c.ad_name) and d.campanha ilike '%wep%');

-- (c) ad_ids que passam a ter preview (esperado: 156):
select count(*) as ad_ids_cobertos from mkt_wep.dim_anuncios d
 where d.campanha ilike '%wep%'
   and exists (select 1 from mkt_wep.criativos_drive c where lower(c.ad_name) = lower(d.anuncio));

-- (d) Sem arquivo no Drive — ficam fora da fila (esperado: 15):
select count(*) as sem_arquivo from mkt_wep.criativos_drive
 where coalesce(drive_feed_id, drive_story_id) is null;

-- (e) Fila inicial:
select * from mkt_wep.fn_criativos_drive_pendentes(5);
