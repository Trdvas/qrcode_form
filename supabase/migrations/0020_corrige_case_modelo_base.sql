-- ============================================================================
-- Corrige um bug na própria 0019: as atualizações de modelo_base pras
-- famílias ONIX, SPIN, IDEA e PALIO usavam "modelo in (...)" com os
-- literais em Title Case ("Onix", "Palio") -- mas Chevrolet e Fiat gravam
-- o campo modelo em CAIXA ALTA ("ONIX", "PALIO"). Comparação de texto
-- "in (...)" é sensível a maiúsculas/minúsculas, então o update bateu
-- ZERO linhas nessas 4 famílias -- sem erro nenhum, silenciosamente
-- (confirmado pela auditoria da 0019: elas apareceram como "unificado =
-- false", ou seja, modelo_base continuou igual a modelo, sem agrupar).
--
-- Correção: refaz essas 4 famílias comparando por upper(trim(modelo)),
-- insensível a caixa -- e, por segurança, passa TODAS as famílias da 0019
-- a usar o mesmo padrão case-insensitive, pra não depender de acertar a
-- grafia exata usada em cada marca.
-- ============================================================================

update veiculos_motor set modelo_base = 'Onix'
where montadora ilike 'chevrolet'
  and upper(trim(modelo)) in ('ONIX', 'ONIX (5 VEL)', 'ONIX (6 VEL)', 'ONIX / ONIX PLUS', 'ONIX/ONIX JOY (6 VEL)');

update veiculos_motor set modelo_base = 'S10'
where montadora ilike 'chevrolet'
  and upper(trim(modelo)) in ('S10', 'S10 (4X2)', 'S10 (4X4)');

update veiculos_motor set modelo_base = 'Spin'
where montadora ilike 'chevrolet'
  and upper(trim(modelo)) in ('SPIN', 'SPIN (6 VEL)');

update veiculos_motor set modelo_base = 'Idea'
where montadora ilike 'fiat'
  and upper(trim(modelo)) in ('IDEA', 'IDEA ADVENTURE');

update veiculos_motor set modelo_base = 'Palio'
where montadora ilike 'fiat'
  and upper(trim(modelo)) in ('PALIO', 'PALIO - NOVO PALIO', 'PALIO ADVENTURE', 'PALIO WEEKEND');

update veiculos_motor set modelo_base = 'Fiesta'
where montadora ilike 'ford'
  and upper(trim(modelo)) in ('FIESTA', 'FIESTA - NEW FIESTA HATCH', 'FIESTA - NEW FIESTA HATCH / SEDAN');

update veiculos_motor set modelo_base = 'Focus'
where montadora ilike 'ford'
  and upper(trim(modelo)) in ('FOCUS', 'FOCUS - NOVO FOCUS HATCH');

update veiculos_motor set modelo_base = 'Ka'
where montadora ilike 'ford'
  and upper(trim(modelo)) in ('KA', 'KA - NEW KA');

update veiculos_motor set modelo_base = 'Mustang GT'
where montadora ilike 'ford'
  and upper(trim(modelo)) in ('MUSTANG GT', 'MUSTANG GT PREMIUM / BLACK SHADOW');

update veiculos_motor set modelo_base = 'Cerato'
where montadora ilike 'kia'
  and upper(trim(modelo)) in ('CERATO', 'CERATO KOUP');

update veiculos_motor set modelo_base = '207'
where montadora ilike 'peugeot'
  and upper(trim(modelo)) in ('207', '207 SW');

update veiculos_motor set modelo_base = 'Jetta'
where montadora ilike 'volkswagen'
  and upper(trim(modelo)) in ('JETTA', 'JETTA / JETTA VARIANT');

update veiculos_motor set modelo_base = 'Golf'
where montadora ilike 'volkswagen'
  and upper(trim(modelo)) in ('GOLF', 'GOLF VARIANT');

update veiculos_motor set modelo_base = 'Duster'
where montadora ilike 'renault'
  and upper(trim(modelo)) in ('DUSTER', 'DUSTER OROCH');

update veiculos_motor set modelo_base = 'Gol'
where montadora ilike 'volkswagen'
  and upper(trim(modelo)) in ('GOL VI', 'GOL VII');

-- Conferência: repete a auditoria da 0019. Agora devem aparecer 15 famílias
-- com unificado = true (as 10 que já funcionavam + Onix, S10, Spin, Idea,
-- Palio) -- e Gol VI/Gol VII não aparece aqui porque "Gol" sozinho não é
-- um modelo cadastrado (não existe par pra comparar nesta auditoria) --
-- esse caso já foi validado separadamente pelo teste funcional (consultar
-- Gol/2017/1.6).
with modelos as (
  select distinct montadora, modelo, modelo_base,
    trim(regexp_replace(regexp_replace(upper(modelo), '[^A-Z0-9]', ' ', 'g'), '\s+', ' ', 'g')) as norm_words
  from veiculos_motor
)
select
  a.montadora,
  a.modelo as modelo_curto,
  b.modelo as modelo_longo,
  a.modelo_base as base_curto,
  b.modelo_base as base_longo,
  (a.modelo_base = b.modelo_base) as unificado
from modelos a
join modelos b
  on a.montadora = b.montadora
  and a.modelo <> b.modelo
  and b.norm_words like a.norm_words || ' %'
order by unificado desc, a.montadora, a.modelo, b.modelo;

-- Confere especificamente as 4 famílias que estavam quebradas.
select montadora, modelo_base, string_agg(distinct modelo, ' | ' order by modelo) as variantes
from veiculos_motor
where montadora ilike any (array['chevrolet', 'fiat'])
  and modelo_base in ('Onix', 'Spin', 'Idea', 'Palio')
group by montadora, modelo_base
order by montadora, modelo_base;

-- Teste funcional: confirma que Gol continua funcionando (o update acima
-- é idempotente, reafirma o que a 0019 já tinha feito certo pro VW).
select * from consultar_orcamento_motor('Gol', 'Volkswagen', '2017', '1.6');
