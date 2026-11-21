-- ============================================================================
-- Corrige um bug pré-existente (desde a 0005) em consultar_orcamento_motor e
-- registrar_orcamento_motor: o casamento de modelo usava LIKE '%...%' nos
-- dois sentidos (modelo normalizado do banco contra o modelo normalizado que
-- o cliente informou), o que faz nomes de modelo que são substring um do
-- outro colidirem -- ex: "Fox" bate em "Spacefox" (SPACEFOX contém FOX),
-- "Gol" bate em "Golf" e em "Gol VI"/"Gol VII" (GOLF e GOLVI contêm GOL).
--
-- Isso ficou visível agora porque, com a marcação de padrao_ambiguidade
-- (0014/0015/0016), um veículo "Fox 1.6 2016" passou a juntar, na mesma
-- consulta, uma linha do Fox E uma do Spacefox (cada um com sua própria
-- versão padrão marcada) -- duas motorizações "padrão" diferentes faziam a
-- função desistir e devolver "ambiguo" de novo, mesmo com tudo certo.
--
-- Mas o problema é mais amplo que a versão padrão: mesmo antes dela existir,
-- uma consulta por "Fox" já misturava silenciosamente as opções de óleo do
-- Spacefox nas respostas (e uma consulta por "Gol" misturava Golf e Gol
-- VI/VII) sempre que caía no caminho "motor único identificado, retorna
-- todas as opções de óleo".
--
-- Correção: troca o LIKE por igualdade exata entre os nomes já normalizados
-- (maiúsculas, sem espaços/pontuação) -- mantém a tolerância a diferenças de
-- caixa/espaçamento/pontuação (ex: "RAV 4" = "RAV4"), só elimina o
-- casamento por substring.
-- ============================================================================

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
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
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
    where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
      and trim(lower(v.montadora)) = trim(lower(p_montadora))
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
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
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
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
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
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
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
    where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
      and trim(lower(v.montadora)) = trim(lower(p_montadora))
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
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
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

-- Conferência: Fox/2016/1.6 agora deve vir "ok_versao_padrao" (não "ambiguo"),
-- usando só as opções de óleo do Fox 1.6 MSI 16V (sem misturar Spacefox).
select * from consultar_orcamento_motor('Fox', 'Volkswagen', '2016', '1.6');
