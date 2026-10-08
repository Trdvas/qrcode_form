-- ============================================================================
-- Corrige um bug real encontrado na segunda rodada de testes: "Citroen"
-- (sem acento) não encontrava nada, enquanto "Citroën" (com acento)
-- funcionava -- porque o casamento de montadora é igualdade exata depois
-- de lower()/trim(), sem nenhuma tolerância a acento. Isso é um risco
-- real: transcrição de áudio e boa parte dos clientes digitando no
-- WhatsApp escrevem sem acento.
--
-- O mesmo problema existe (de um jeito diferente, mais sutil) no
-- casamento de modelo: a normalização atual (regexp_replace removendo
-- tudo que não é [A-Z0-9]) APAGA letras acentuadas em vez de convertê-las
-- -- "Híbrido" vira "HBRIDO" (perde o I), enquanto "Hibrido" (sem acento)
-- vira "HIBRIDO" -- os dois NÃO ficam iguais. Isso afeta, por exemplo,
-- "Fusion Híbrido".
--
-- A extensão unaccent não está instalada neste banco (confirmado via
-- pg_extension), então a correção é manual: uma função que troca cada
-- vogal acentuada comum (português/francês) pela versão sem acento, ANTES
-- de qualquer outra normalização.
-- ============================================================================

create or replace function normalizar_acentos(txt text)
returns text
language sql
immutable
as $$
  select translate(
    lower(trim(coalesce(txt, ''))),
    'áàâãäéèêëíìîïóòôõöúùûüçñ',
    'aaaaaeeeeiiiiooooouuuucn'
  )
$$;

-- veiculo_modelo_bate: normaliza acento antes de remover o resto da
-- pontuação (em vez de só apagar a letra acentuada).
create or replace function veiculo_modelo_bate(v_modelo text, v_modelo_base text, p_modelo text)
returns boolean
language sql
immutable
as $$
  select
    regexp_replace(upper(normalizar_acentos(v_modelo)), '[^A-Z0-9]', '', 'g')
      = regexp_replace(upper(normalizar_acentos(p_modelo)), '[^A-Z0-9]', '', 'g')
    or
    regexp_replace(upper(normalizar_acentos(v_modelo_base)), '[^A-Z0-9]', '', 'g')
      = regexp_replace(upper(normalizar_acentos(p_modelo)), '[^A-Z0-9]', '', 'g')
$$;

create or replace function consultar_orcamento_motor(p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, veiculo text, marca text, especificacao text, viscosidade text, litros numeric, valor_oleo numeric, valor_filtro numeric, valor_mao_obra numeric, valor_total numeric)
language plpgsql
as $$
declare
  v_count int;
  v_motores_distintos int;
  v_litros_min numeric;
  v_litros_max numeric;
  v_motor text;
  v_ano int;
  v_ano_fim_escolhido int;
  v_litros_escolhido numeric;
  v_motor_escolhido text;
  v_count_padrao int;
  v_status text;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::text, null::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  select count(*), count(distinct lower(coalesce(v.motor_descricao, ''))),
    min(v.litros_oleo_motor), max(v.litros_oleo_motor)
  into v_count, v_motores_distintos, v_litros_min, v_litros_max
  from veiculos_motor v
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
    and normalizar_acentos(v.montadora) = normalizar_acentos(p_montadora)
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null;

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::text, null::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  v_status := 'ok';

  if v_count > 1 and (v_motores_distintos > 1 or (v_litros_max - v_litros_min) > 0.3) then
    select v.motor_descricao, count(*) over ()
    into v_motor_escolhido, v_count_padrao
    from veiculos_motor v
    where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
      and normalizar_acentos(v.montadora) = normalizar_acentos(p_montadora)
      and v_ano between v.ano_inicio and v.ano_fim
      and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
      and v.produto_oleo_motor_id is not null
      and v.servico_motor_id is not null
      and v.padrao_ambiguidade = true;

    if coalesce(v_count_padrao, 0) <> 1 then
      return query select 'ambiguo'::text, null::text, null::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric, null::numeric;
      return;
    end if;

    v_status := 'ok_versao_padrao';
    v_motor := v_motor_escolhido;
  end if;

  select v.ano_fim, v.litros_oleo_motor into v_ano_fim_escolhido, v_litros_escolhido
  from veiculos_motor v
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
    and normalizar_acentos(v.montadora) = normalizar_acentos(p_montadora)
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null
  order by v.ano_fim desc, v.litros_oleo_motor desc
  limit 1;

  return query
  select v_status,
    v.modelo || ' ' || v.montadora,
    p.marca,
    p.especificacao,
    p.viscosidade,
    v.litros_oleo_motor,
    ceil(v.litros_oleo_motor) * p.preco_litro,
    coalesce(f.preco, 0),
    s.preco_mao_obra,
    (ceil(v.litros_oleo_motor) * p.preco_litro) + coalesce(f.preco, 0) + s.preco_mao_obra
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  left join filtros f on f.id = v.filtro_oleo_motor_id
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
    and normalizar_acentos(v.montadora) = normalizar_acentos(p_montadora)
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null
    and v.ano_fim = v_ano_fim_escolhido
    and v.litros_oleo_motor = v_litros_escolhido
  order by valor_total asc;
end;
$$;

create or replace function registrar_orcamento_motor(p_session_id text, p_modelo text, p_montadora text, p_ano text, p_motor text default null, p_viscosidade text default null)
returns table(status text, orcamento_id uuid, veiculo text, valor_total numeric)
language plpgsql
as $$
declare
  v_veiculo text;
  v_valor numeric;
  v_count int;
  v_motores_distintos int;
  v_litros_min numeric;
  v_litros_max numeric;
  v_orcamento_id uuid;
  v_motor text;
  v_motor_escolhido text;
  v_count_padrao int;
  v_viscosidade text;
  v_ano int;
  v_id_escolhido uuid;
  v_status_base text;
begin
  v_motor := nullif(trim(p_motor), '');
  v_viscosidade := nullif(trim(p_viscosidade), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select count(*), count(distinct lower(coalesce(v.motor_descricao, ''))),
    min(v.litros_oleo_motor), max(v.litros_oleo_motor)
  into v_count, v_motores_distintos, v_litros_min, v_litros_max
  from veiculos_motor v
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
    and normalizar_acentos(v.montadora) = normalizar_acentos(p_montadora)
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null;

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  v_status_base := 'ok';

  if v_count > 1 and (v_motores_distintos > 1 or (v_litros_max - v_litros_min) > 0.3) then
    select v.motor_descricao, count(*) over ()
    into v_motor_escolhido, v_count_padrao
    from veiculos_motor v
    where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
      and normalizar_acentos(v.montadora) = normalizar_acentos(p_montadora)
      and v_ano between v.ano_inicio and v.ano_fim
      and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
      and v.produto_oleo_motor_id is not null
      and v.servico_motor_id is not null
      and v.padrao_ambiguidade = true;

    if coalesce(v_count_padrao, 0) <> 1 then
      return query select 'ambiguo'::text, null::uuid, null::text, null::numeric;
      return;
    end if;

    v_status_base := 'ok_versao_padrao';
    v_motor := v_motor_escolhido;
  end if;

  select v.id into v_id_escolhido
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
    and normalizar_acentos(v.montadora) = normalizar_acentos(p_montadora)
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null
    and (v_viscosidade is null or trim(lower(p.viscosidade)) = trim(lower(v_viscosidade)))
  order by v.ano_fim desc, (ceil(v.litros_oleo_motor) * p.preco_litro) asc
  limit 1;

  if v_id_escolhido is null then
    return query select 'viscosidade_indisponivel'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select v.modelo || ' ' || v.montadora,
    (ceil(v.litros_oleo_motor) * p.preco_litro) + coalesce(f.preco, 0) + s.preco_mao_obra
  into v_veiculo, v_valor
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  left join filtros f on f.id = v.filtro_oleo_motor_id
  where v.id = v_id_escolhido;

  insert into orcamentos (session_id, veiculo, veiculo_motor_id, valor_total, status)
  values (p_session_id, v_veiculo, v_id_escolhido, v_valor, 'enviado')
  returning id into v_orcamento_id;

  return query select v_status_base, v_orcamento_id, v_veiculo, v_valor;
end;
$$;

-- Conferência: os dois devem dar o MESMO resultado agora (status ok, dados
-- do C4 Citroën 2014).
select 'sem acento' as caso, * from consultar_orcamento_motor('C4', 'Citroen', '2014');
select 'com acento' as caso, * from consultar_orcamento_motor('C4', 'Citroën', '2014');
