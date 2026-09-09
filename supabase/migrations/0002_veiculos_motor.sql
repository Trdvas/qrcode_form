-- ============================================================================
-- Sugestão automática de produto (óleo) para veículos de motor
-- ============================================================================
--
-- `veiculos_motor` já existe em produção (não é criada/alterada por esta
-- migration). Colunas relevantes usadas aqui: id, negocio_id, modelo,
-- montadora, ano_inicio, ano_fim, motor_descricao, litros_oleo_motor,
-- produto_oleo_motor_id, servico_motor_id, viscosidade_recomendada.
--
-- `viscosidade_recomendada` guarda uma ou mais opções separadas por "|",
-- cada uma no formato "GRADE" ou "GRADE (detalhe extra)" — ex.:
-- "5W30 (Sintético)|5W40". A function abaixo casa cada opção com produtos
-- cuja especificação começa com a mesma grade (normalizada, sem espaços/
-- pontuação) e cujo restante da especificação (quando houver) aparece no
-- detalhe extra da opção.
--
-- Só considera veículos ainda sem produto vinculado (produto_oleo_motor_id
-- is null) e só retorna combinações veículo/opção que efetivamente casaram
-- com algum produto — pode haver mais de uma linha por veículo quando mais
-- de uma opção de viscosidade ou mais de um produto casam.
create or replace function public.sugerir_produtos_motor(p_negocio_id uuid)
returns table(
  veiculo_id uuid,
  modelo text,
  montadora text,
  motor_descricao text,
  ano_inicio int,
  ano_fim int,
  opcao_viscosidade text,
  produto_id uuid,
  produto_marca text,
  produto_especificacao text
)
language sql
stable
as $$
  with segmentos as (
    select
      vm.id as veiculo_id,
      vm.modelo, vm.montadora, vm.motor_descricao, vm.ano_inicio, vm.ano_fim,
      trim(seg) as opcao_original,
      upper(regexp_replace(split_part(seg, '(', 1), '[^a-zA-Z0-9]', '', 'g')) as grade_segmento,
      upper(regexp_replace(coalesce(substring(seg from '\((.*)\)'), ''), '[^a-zA-Z0-9]', '', 'g')) as resto_segmento
    from veiculos_motor vm
    cross join lateral unnest(string_to_array(vm.viscosidade_recomendada, '|')) as seg
    where vm.negocio_id = p_negocio_id
      and vm.produto_oleo_motor_id is null
  ),
  produtos_norm as (
    select
      p.id as produto_id, p.marca, p.especificacao,
      upper(regexp_replace(split_part(trim(p.especificacao), ' ', 1), '[^a-zA-Z0-9]', '', 'g')) as grade_produto,
      upper(regexp_replace(substring(trim(p.especificacao) from position(' ' in trim(p.especificacao)) + 1), '[^a-zA-Z0-9]', '', 'g')) as resto_produto
    from produtos p
    where p.negocio_id = p_negocio_id
  )
  select s.veiculo_id, s.modelo, s.montadora, s.motor_descricao, s.ano_inicio, s.ano_fim,
    s.opcao_original, pn.produto_id, pn.marca, pn.especificacao
  from segmentos s
  join produtos_norm pn
    on pn.grade_produto = s.grade_segmento
   and (pn.resto_produto = '' or s.resto_segmento like '%' || pn.resto_produto || '%');
$$;
