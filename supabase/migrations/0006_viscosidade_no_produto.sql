-- ============================================================================
-- Corrige dependência transitiva (3FN): veiculos_motor.viscosidade_recomendada
-- duplicava um dado que já está em produtos.especificacao (ex: "Dual Tec
-- Turbo 5W30" -> a viscosidade "5W30" já está ali). Cada cadastro de veículo
-- exigia manter as duas colunas sincronizadas manualmente, sem nada no banco
-- garantindo essa consistência.
--
-- Solução: a viscosidade passa a ser um atributo do produto
-- (produtos.viscosidade), derivado automaticamente da especificação por
-- trigger (convenção usada em todo o catálogo GT-Oil: a viscosidade é o
-- último token do texto). A coluna redundante em veiculos_motor é removida.
-- ============================================================================

alter table produtos add column if not exists viscosidade text;

create or replace function produtos_derivar_viscosidade()
returns trigger
language plpgsql
as $$
begin
  new.viscosidade := (regexp_match(new.especificacao, '(\d{1,2}W\d{1,2})\s*$', 'i'))[1];
  return new;
end;
$$;

drop trigger if exists trg_produtos_derivar_viscosidade on produtos;
create trigger trg_produtos_derivar_viscosidade
  before insert or update of especificacao
  on produtos
  for each row
  execute function produtos_derivar_viscosidade();

-- Backfill dos produtos já cadastrados (força o trigger "of especificacao"
-- a rodar pra cada linha, sem duplicar a lógica do regex aqui).
update produtos set especificacao = especificacao;

-- Funções do agente de IA: usam produtos.viscosidade em vez da coluna
-- redundante de veiculos_motor.
create or replace function consultar_orcamento_motor(p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, veiculo text, viscosidade text, valor_oleo numeric, valor_filtro numeric, valor_mao_obra numeric, valor_total numeric)
language plpgsql
as $$
declare
  v_count int;
  v_motores_distintos int;
  v_litros_min numeric;
  v_litros_max numeric;
  v_motor text;
  v_ano int;
  v_id_escolhido uuid;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  select count(*), count(distinct lower(coalesce(v.motor_descricao, ''))),
    min(v.litros_oleo_motor), max(v.litros_oleo_motor)
  into v_count, v_motores_distintos, v_litros_min, v_litros_max
  from veiculos_motor v
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null;

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  if v_count > 1 and (v_motores_distintos > 1 or (v_litros_max - v_litros_min) > 0.3) then
    return query select 'ambiguo'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  select v.id into v_id_escolhido
  from veiculos_motor v
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null
  order by v.ano_fim desc, v.litros_oleo_motor desc
  limit 1;

  return query
  select 'ok'::text,
    v.modelo || ' ' || v.montadora,
    p.viscosidade,
    ceil(v.litros_oleo_motor) * p.preco_litro,
    coalesce(f.preco, 0),
    s.preco_mao_obra,
    (ceil(v.litros_oleo_motor) * p.preco_litro) + coalesce(f.preco, 0) + s.preco_mao_obra
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  left join filtros f on f.id = v.filtro_oleo_motor_id
  where v.id = v_id_escolhido;
end;
$$;

-- Remove a coluna redundante (o dado agora vive só em produtos.viscosidade).
alter table veiculos_motor drop column if exists viscosidade_recomendada;
