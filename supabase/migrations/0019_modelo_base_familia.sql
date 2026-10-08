-- ============================================================================
-- Substitui o casamento de modelo por heurística de texto (0017/0018 --
-- igualdade exata, depois prefixo de palavra) por uma solução estrutural:
-- cada linha de veiculos_motor ganha uma coluna modelo_base, que agrupa
-- variantes do MESMO carro (mesma motorização, só muda carroceria/câmbio/
-- acabamento -- ex: "Gol VI"/"Gol VII" -> base "Gol", "Onix (6 vel)" ->
-- base "Onix").
--
-- Por padrão, modelo_base = modelo (cada linha fica isolada -- exige nome
-- completo pra casar). Só agrupamos explicitamente as famílias que
-- confirmamos como seguras (mesmo motor entre as variantes). Modelos com
-- motor genuinamente diferente por trim (híbridos, GTI/Si/RS/GT, PHEV,
-- Sport/Cross como plataforma distinta, etc.) ficam isolados por padrão --
-- sem ação nenhuma precisam, o que já é o comportamento seguro.
--
-- Vantagem sobre a correção anterior (0018, prefixo de palavra): qualquer
-- modelo novo cadastrado no futuro nasce isolado por padrão. Uma colisão
-- do tipo Fox/Spacefox só passa a existir se alguém explicitamente marcar
-- o mesmo modelo_base pras duas linhas -- não é mais possível ela
-- acontecer "sozinha" por coincidência de texto.
-- ============================================================================

alter table veiculos_motor add column if not exists modelo_base text;

update veiculos_motor set modelo_base = modelo where modelo_base is null;

alter table veiculos_motor alter column modelo_base set not null;

-- Garante que todo INSERT/UPDATE futuro que não informar modelo_base
-- explicitamente continua isolado por padrão (modelo_base = modelo).
create or replace function veiculos_motor_default_modelo_base()
returns trigger
language plpgsql
as $$
begin
  if new.modelo_base is null or trim(new.modelo_base) = '' then
    new.modelo_base := new.modelo;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_veiculos_motor_default_modelo_base on veiculos_motor;
create trigger trg_veiculos_motor_default_modelo_base
before insert or update on veiculos_motor
for each row execute function veiculos_motor_default_modelo_base();

-- ----------------------------------------------------------------------------
-- Famílias confirmadas como seguras (mesmo motor entre as variantes) --
-- "Grupo A" da análise feita com o usuário.
-- ----------------------------------------------------------------------------

update veiculos_motor set modelo_base = 'Onix'
where montadora ilike 'chevrolet' and modelo in ('Onix', 'Onix (5 vel)', 'Onix (6 vel)', 'Onix / Onix Plus', 'Onix/Onix Joy (6 vel)');

update veiculos_motor set modelo_base = 'S10'
where montadora ilike 'chevrolet' and modelo in ('S10', 'S10 (4x2)', 'S10 (4x4)');

update veiculos_motor set modelo_base = 'Spin'
where montadora ilike 'chevrolet' and modelo in ('Spin', 'Spin (6 vel)');

update veiculos_motor set modelo_base = 'Idea'
where montadora ilike 'fiat' and modelo in ('Idea', 'Idea Adventure');

update veiculos_motor set modelo_base = 'Palio'
where montadora ilike 'fiat' and modelo in ('Palio', 'Palio - Novo Palio', 'Palio Adventure', 'Palio Weekend');

update veiculos_motor set modelo_base = 'Fiesta'
where montadora ilike 'ford' and modelo in ('Fiesta', 'Fiesta - New Fiesta Hatch', 'Fiesta - New Fiesta Hatch / Sedan');

update veiculos_motor set modelo_base = 'Focus'
where montadora ilike 'ford' and modelo in ('Focus', 'Focus - Novo Focus Hatch');

update veiculos_motor set modelo_base = 'Ka'
where montadora ilike 'ford' and modelo in ('Ka', 'Ka - New Ka');

update veiculos_motor set modelo_base = 'Mustang GT'
where montadora ilike 'ford' and modelo in ('Mustang GT', 'Mustang GT Premium / Black Shadow');

update veiculos_motor set modelo_base = 'Cerato'
where montadora ilike 'kia' and modelo in ('Cerato', 'Cerato Koup');

update veiculos_motor set modelo_base = '207'
where montadora ilike 'peugeot' and modelo in ('207', '207 SW');

update veiculos_motor set modelo_base = 'Jetta'
where montadora ilike 'volkswagen' and modelo in ('Jetta', 'Jetta / Jetta Variant');

update veiculos_motor set modelo_base = 'Golf'
where montadora ilike 'volkswagen' and modelo in ('Golf', 'Golf Variant');

update veiculos_motor set modelo_base = 'Duster'
where montadora ilike 'renault' and modelo in ('Duster', 'Duster Oroch');

-- Gol VI/VII: mesmo caso motivador original (geração como sufixo, cliente
-- normalmente não sabe informar "VI" ou "VII" -- o ano já desambigua).
update veiculos_motor set modelo_base = 'Gol'
where montadora ilike 'volkswagen' and modelo in ('Gol VI', 'Gol VII');

-- Todo o resto (Fusion Híbrido, Civic Si, Lancer Evolution X, Outlander
-- PHEV/Sport, Pajero Sport/TR4/Dakar/Full, Corolla Cross/Altis Hybrid,
-- RAV 4 S Hybrid, Golf GTE Hybrid/GTI/"Golf/GT", Sandero RS, Fluence GT,
-- 208 GT, Novo Polo/GTS, Polo IV/GT, Jimny Sierra, C4 Cactus/Lounge/
-- Pallas/Picasso, Strada Pick Up - Freedom/Volcano, Renegade (4x4), Jetta
-- GLi) fica com modelo_base = modelo (isolado) -- comportamento padrão,
-- nenhuma ação necessária. Se confirmar que algum desses tem o mesmo motor
-- da versão base, é só rodar um update igual aos de cima depois.

-- ----------------------------------------------------------------------------
-- Casamento de modelo: agora só igualdade exata (do nome completo OU da
-- família), sem heurística de prefixo/substring nenhuma.
-- ----------------------------------------------------------------------------

drop function if exists veiculo_modelo_bate(text, text);

create or replace function veiculo_modelo_bate(v_modelo text, v_modelo_base text, p_modelo text)
returns boolean
language sql
immutable
as $$
  select
    regexp_replace(upper(v_modelo), '[^A-Z0-9]', '', 'g')
      = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
    or
    regexp_replace(upper(v_modelo_base), '[^A-Z0-9]', '', 'g')
      = regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g')
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
    where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
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
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
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
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
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
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
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
    where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
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
  where veiculo_modelo_bate(v.modelo, v.modelo_base, p_modelo)
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

-- ----------------------------------------------------------------------------
-- Conferência
-- ----------------------------------------------------------------------------

-- Fox: deve vir ok_versao_padrao, só com dados do Fox (Spacefox/Crossfox
-- têm modelo_base próprio, isolado por padrão).
select * from consultar_orcamento_motor('Fox', 'Volkswagen', '2016', '1.6');

-- Gol: deve vir ok_versao_padrao, só com dados do Gol VII (Gol VI e Gol VII
-- compartilham modelo_base = 'Gol', mas o ano 2017 só bate na faixa do
-- Gol VII).
select * from consultar_orcamento_motor('Gol', 'Volkswagen', '2017', '1.6');

-- Famílias que passaram a compartilhar modelo_base (deve mostrar cada
-- família agrupada).
select montadora, modelo_base, string_agg(distinct modelo, ' | ' order by modelo) as variantes
from veiculos_motor
where modelo_base <> modelo
group by montadora, modelo_base
order by montadora, modelo_base;
