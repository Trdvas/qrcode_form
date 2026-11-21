-- ============================================================================
-- Resolve o "Bloco 2" da varredura de ambiguidade (0014/0015): grupos em que
-- a motorização varia (geração do motor: MPI 8V vs MSI 16V/8V, ou GDI vs MPI
-- no caso do Sorento), mas a litragem de óleo é idêntica ou está dentro da
-- tolerância (<= 0.3L) -- e, confirmado por consulta, as OPÇÕES DE ÓLEO
-- cadastradas (marca/especificação/viscosidade) são as mesmas em cada grupo,
-- independente da variante.
--
-- Como o óleo recomendado já é o mesmo não importa qual variante o cliente
-- tenha de fato -- critério do usuário: "se a litragem é idêntica ou está
-- dentro do desvio padrão, utilize como critério de escolha qualquer um dos
-- modelos que tiverem compatibilidade de aplicação do óleo" (mesma lógica já
-- usada na correção do Chevrolet S10 2.0). Critério de desempate usado aqui:
-- faixa de ano mais recente (ano_fim maior); empatando, prioriza a
-- especificação de motor mais nova (MSI/16V sobre MPI/8V).
-- ============================================================================

-- Garante a coluna mesmo se as migrations anteriores ainda não rodaram.
alter table veiculos_motor
  add column if not exists padrao_ambiguidade boolean not null default false;

-- Fox 1.0: "L3 MPI 12V" (2014-2018) vence "L4 MPI 8V" (2013-2015) por ano_fim mais recente.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'fox'
  and motor_descricao = '1.0 L3 MPI 12V (F)';

-- Fox 1.6: "MSI 16V" (até 2021) vence "MPI 8V" (até 2018).
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'fox'
  and motor_descricao = '1.6 L4 MSI 16V (F)';

-- Gol VI 1.6: "MSI 16V" e "MSI 8V" têm a mesma faixa de ano (2015-2016); desempate por 16V.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'gol vi'
  and motor_descricao = '1.6 L4 MSI 16V (F)';

-- Gol VII 1.6: mesma faixa de ano (2017-2022) entre "MSI 16V" e "MSI 8V"; desempate por 16V.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'gol vii'
  and motor_descricao = '1.6 L4 MSI 16V (F)';

-- Golf 1.6: mesma faixa de ano (2013-2014) entre "MPI 16V" e "MPI 8V"; desempate por 16V.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'golf'
  and motor_descricao = '1.6 L4 MPI 16V (F)';

-- Saveiro 1.6 (3 vias): "MSI 16V" e "MSI 8V" vão até 2023 (vs "MPI 8V" até 2015); desempate por 16V.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'saveiro'
  and motor_descricao = '1.6 L4 MSI 16V (F)';

-- Spacecross 1.6: "MSI 16V" (até 2017) vence "MPI 8V" (até 2015).
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'spacecross'
  and motor_descricao = '1.6 L4 MSI 16V (F)';

-- Spacefox 1.6: "MPI 8V" (até 2019) vence "MSI 16V" (até 2018) por ano_fim mais recente.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'spacefox'
  and motor_descricao = '1.6 L4 MPI 8V (F)';

-- Voyage 1.6: mesma faixa final de ano (até 2022) entre "MPI 8V" e "MSI 16V"; desempate por 16V.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'voyage'
  and motor_descricao = '1.6 L4 MSI 16V (F)';

-- Sorento 2.4 (Kia): "GDI 16V" (2015-2023) vence "MPI 16V" (2013-2015) por ano_fim mais recente.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'kia'
  and modelo ilike 'sorento'
  and motor_descricao = '2.4 L4 GDI 16V (G)';

-- Conferência: deve retornar 16 linhas (as 9 novas aqui + as 7 já marcadas em 0014/0015).
select montadora, modelo, motor_descricao, padrao_ambiguidade
from veiculos_motor
where padrao_ambiguidade = true
order by montadora, modelo;
