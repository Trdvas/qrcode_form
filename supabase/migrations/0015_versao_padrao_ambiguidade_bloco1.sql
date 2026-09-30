-- ============================================================================
-- Continuação da 0014: varredura completa de veiculos_motor encontrou mais
-- 17 grupos com o mesmo padrão da Amarok (mesma cilindrada informada pelo
-- cliente, faixas de ano sobrepostas, mesma litragem de óleo -- ou seja,
-- nenhuma pergunta que o agente possa fazer ao cliente resolveria a
-- ambiguidade sozinha).
--
-- Desses 17, 6 têm um padrão claro de "versão dominante" (motor a álcool/
-- flex é a opção comum/mais vendida, enquanto a outra motorização do mesmo
-- grupo é só gasolina pura ou só turbo/diesel, minoritária no mercado
-- brasileiro) -- mesmo raciocínio já aplicado à Amarok em 0014. Esses 6 são
-- marcados aqui como padrao_ambiguidade = true.
--
-- Os outros 9 grupos (todos variações internas de motorização dentro da
-- própria VW -- ex. MPI 8V vs MSI 16V/8V -- mais um caso Kia Sorento GDI vs
-- MPI) NÃO têm uma versão obviamente dominante sem conhecimento real da
-- base de clientes do usuário, e foram deixados de propósito como
-- "ambiguo" por enquanto, a pedido do usuário.
-- ============================================================================

-- ASX (Mitsubishi): 2.0 Flex é a versão dominante; a outra opção do grupo
-- é 2.0 gasolina puro, bem mais rara.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'mitsubishi'
  and modelo ilike 'asx'
  and motor_descricao = '2.0 L4 MPI 16V (F)';

-- Cerato (Kia): 1.6 Flex é a versão dominante no grupo de mesma cilindrada.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'kia'
  and modelo ilike 'cerato'
  and motor_descricao = '1.6 L4 MPI 16V (F)';

-- Tiguan (Volkswagen): 1.4 TSI Flex é a versão dominante; a outra opção do
-- grupo é turbo importado, bem mais rara no mercado nacional.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'volkswagen'
  and modelo ilike 'tiguan'
  and motor_descricao = '1.4 L4 TSFI/TB 16V (F)';

-- HB20 (Hyundai): 1.0 Flex é a versão dominante do grupo de mesma cilindrada.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'hyundai'
  and modelo ilike 'hb20'
  and motor_descricao = '1.0 Flex';

-- Fiat 500 (Fiat): 1.4 Flex é a versão dominante do grupo de mesma cilindrada.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'fiat'
  and modelo ilike '500'
  and motor_descricao = '1.4 Flex';

-- Mobi (Fiat): 1.0 Flex é a versão dominante do grupo de mesma cilindrada.
update veiculos_motor
set padrao_ambiguidade = true
where montadora ilike 'fiat'
  and modelo ilike 'mobi'
  and motor_descricao = '1.0 Flex';

-- Conferência: deve retornar 7 linhas (as 6 novas + a Amarok já marcada na 0014).
select montadora, modelo, motor_descricao, padrao_ambiguidade
from veiculos_motor
where padrao_ambiguidade = true
order by montadora, modelo;
