-- ============================================================================
-- Estrutura de dados do agente de IA (catálogo de veículos, buffer de
-- mensagens e funções de orçamento/agendamento) — negócio único, sem
-- segmentação por negocio_id.
-- ============================================================================

create extension if not exists "btree_gist";

-- ----------------------------------------------------------------------------
-- Tabelas
-- ----------------------------------------------------------------------------

alter table negocio add column if not exists waha_session text;

-- Trava de sobreposição: nenhum agendamento confirmado pode se sobrepor a
-- outro (equivalente à exclusion constraint que existia por negocio_id).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'agendamentos_sem_sobreposicao'
  ) then
    alter table agendamentos
      add constraint agendamentos_sem_sobreposicao
      exclude using gist (tstzrange(data_hora_inicio, data_hora_fim) with &&)
      where (status = 'confirmado');
  end if;
end $$;

create table if not exists filtros (
  id uuid primary key default gen_random_uuid(),
  codigo text not null,
  descricao text,
  preco numeric(10, 2) not null check (preco >= 0),
  criado_em timestamptz not null default now()
);

create table if not exists veiculos (
  id uuid primary key default gen_random_uuid(),
  modelo text not null,
  montadora text not null,
  ano integer not null,
  motor text,
  tipo_cambio text not null,
  litros_oleo_cambio numeric(10, 2) not null check (litros_oleo_cambio >= 0),
  litros_oleo_limpeza numeric(10, 2) default 0 check (litros_oleo_limpeza >= 0),
  produto_oleo_id uuid references produtos (id) on delete set null,
  servico_id uuid references servicos (id) on delete set null,
  filtro_externo_id uuid references filtros (id) on delete set null,
  filtro_interno_id uuid references filtros (id) on delete set null
);

-- UNIQUE como table constraint não aceita expressões — usa índice único.
create unique index if not exists veiculos_sem_duplicata on veiculos (
  lower(modelo), lower(montadora), ano, lower(coalesce(motor, ''))
);

create table if not exists veiculos_motor (
  id uuid primary key default gen_random_uuid(),
  modelo text not null,
  montadora text not null,
  ano_inicio integer not null,
  ano_fim integer not null,
  motor_descricao text,
  litros_oleo_motor numeric(10, 2) not null check (litros_oleo_motor >= 0),
  produto_oleo_motor_id uuid references produtos (id) on delete set null,
  servico_motor_id uuid references servicos (id) on delete set null,
  filtro_oleo_motor_id uuid references filtros (id) on delete set null,
  viscosidade_recomendada text,
  constraint veiculos_motor_sem_sobreposicao exclude using gist (
    lower(modelo) with =,
    lower(montadora) with =,
    lower(coalesce(motor_descricao, '')) with =,
    int4range(ano_inicio, ano_fim + 1) with &&
  )
);

create table if not exists mensagens_buffer (
  id uuid primary key default gen_random_uuid(),
  session_id text not null,
  texto text not null,
  criado_em timestamptz not null default now()
);

create index if not exists idx_veiculos_busca on veiculos (lower(modelo), lower(montadora), ano);
create index if not exists idx_veiculos_motor_busca on veiculos_motor (montadora, ano_inicio, ano_fim);
create index if not exists idx_mensagens_buffer_session on mensagens_buffer (session_id, criado_em);

-- ----------------------------------------------------------------------------
-- RLS (mesmo padrão das demais tabelas operacionais: qualquer perfil acessa.
-- Não afeta a conexão direta do n8n, que usa credencial Postgres própria e
-- não passa pelo cliente Supabase/anon key sujeito a RLS.)
-- ----------------------------------------------------------------------------

alter table filtros enable row level security;
alter table veiculos enable row level security;
alter table veiculos_motor enable row level security;
alter table mensagens_buffer enable row level security;

create policy "filtros_all" on filtros for all
  using (auth_has_perfil()) with check (auth_has_perfil());

create policy "veiculos_all" on veiculos for all
  using (auth_has_perfil()) with check (auth_has_perfil());

create policy "veiculos_motor_all" on veiculos_motor for all
  using (auth_has_perfil()) with check (auth_has_perfil());

create policy "mensagens_buffer_all" on mensagens_buffer for all
  using (auth_has_perfil()) with check (auth_has_perfil());

-- ----------------------------------------------------------------------------
-- Funções: removido o parâmetro p_negocio_id de todas (negócio único).
-- ----------------------------------------------------------------------------

drop function if exists consultar_horarios_disponiveis(text, text, text);
create or replace function consultar_horarios_disponiveis(p_data text, p_duracao_horas text default '4')
returns table(horario_inicio text, horario_fim text)
language plpgsql
as $$
declare
  v_data date;
  v_duracao numeric;
begin
  v_data := nullif(trim(p_data), '')::date;
  v_duracao := coalesce(nullif(regexp_replace(coalesce(p_duracao_horas, ''), '[^0-9.]', '', 'g'), ''), '4')::numeric;
  if v_data is null then
    return;
  end if;

  return query
  select to_char(slot, 'HH24:MI'), to_char(slot + (v_duracao || ' hours')::interval, 'HH24:MI')
  from generate_series(
    (v_data + time '08:00')::timestamptz,
    (v_data + time '16:00')::timestamptz - (v_duracao || ' hours')::interval,
    interval '1 hour'
  ) as slot
  where not exists (
    select 1 from agendamentos a
    where a.status = 'confirmado'
      and tstzrange(a.data_hora_inicio, a.data_hora_fim) && tstzrange(slot, slot + (v_duracao || ' hours')::interval)
  );
end;
$$;

drop function if exists consultar_orcamento(text, text, text, text, text);
create or replace function consultar_orcamento(p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, veiculo text, valor_oleo numeric, valor_filtros numeric, valor_mao_obra numeric, valor_total numeric)
language plpgsql
as $$
declare
  v_count int;
  v_motor text;
  v_ano int;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  select count(*) into v_count from veiculos v
  where trim(lower(v.modelo)) = trim(lower(p_modelo))
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v.ano = v_ano
    and (v_motor is null or trim(lower(v.motor)) = trim(lower(v_motor)));

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  elsif v_count > 1 then
    return query select 'ambiguo'::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  return query
  select 'ok'::text,
    v.modelo || ' ' || v.montadora || ' ' || v.ano::text,
    (v.litros_oleo_cambio + coalesce(v.litros_oleo_limpeza, 0)) * p.preco_litro,
    coalesce(f_ext.preco, 0) + coalesce(f_int.preco, 0),
    s.preco_mao_obra,
    (v.litros_oleo_cambio + coalesce(v.litros_oleo_limpeza, 0)) * p.preco_litro
      + coalesce(f_ext.preco, 0) + coalesce(f_int.preco, 0) + s.preco_mao_obra
  from veiculos v
  join produtos p on p.id = v.produto_oleo_id
  join servicos s on s.id = v.servico_id
  left join filtros f_ext on f_ext.id = v.filtro_externo_id
  left join filtros f_int on f_int.id = v.filtro_interno_id
  where trim(lower(v.modelo)) = trim(lower(p_modelo))
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v.ano = v_ano
    and (v_motor is null or trim(lower(v.motor)) = trim(lower(v_motor)));
end;
$$;

drop function if exists consultar_orcamento_motor(text, text, text, text, text);
create or replace function consultar_orcamento_motor(p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, veiculo text, viscosidade text, valor_oleo numeric, valor_filtro numeric, valor_mao_obra numeric, valor_total numeric)
language plpgsql
as $$
declare
  v_count int;
  v_motor text;
  v_ano int;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  select count(*) into v_count from veiculos_motor v
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null;

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  elsif v_count > 1 then
    return query select 'ambiguo'::text, null::text, null::text, null::numeric, null::numeric, null::numeric, null::numeric;
    return;
  end if;

  return query
  select 'ok'::text,
    v.modelo || ' ' || v.montadora,
    v.viscosidade_recomendada,
    ceil(v.litros_oleo_motor) * p.preco_litro,
    coalesce(f.preco, 0),
    s.preco_mao_obra,
    (ceil(v.litros_oleo_motor) * p.preco_litro) + coalesce(f.preco, 0) + s.preco_mao_obra
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  left join filtros f on f.id = v.filtro_oleo_motor_id
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%');
end;
$$;

drop function if exists criar_agendamento(text, text, text, text, text, text);
create or replace function criar_agendamento(p_session_id text, p_veiculo text, p_data text, p_hora_inicio text, p_duracao_horas text default '4')
returns table(status text, agendamento_id uuid, inicio text, fim text)
language plpgsql
as $$
declare
  v_inicio timestamptz;
  v_fim timestamptz;
  v_id uuid;
  v_duracao numeric;
begin
  v_duracao := coalesce(nullif(regexp_replace(coalesce(p_duracao_horas, ''), '[^0-9.]', '', 'g'), ''), '4')::numeric;
  v_inicio := (nullif(trim(p_data), '') || ' ' || nullif(trim(p_hora_inicio), ''))::timestamptz;
  if v_inicio is null then
    return query select 'dados_invalidos'::text, null::uuid, null::text, null::text;
    return;
  end if;
  v_fim := v_inicio + (v_duracao || ' hours')::interval;

  -- Trava: não permite serviço passar das 16h nem começar antes das 8h
  if (v_inicio::time < time '08:00') or (v_fim::time > time '16:00') then
    return query select 'fora_do_horario'::text, null::uuid, null::text, null::text;
    return;
  end if;

  begin
    insert into agendamentos (session_id, veiculo, data_hora_inicio, data_hora_fim, status)
    values (p_session_id, p_veiculo, v_inicio, v_fim, 'confirmado')
    returning id into v_id;
  exception when exclusion_violation then
    return query select 'conflito'::text, null::uuid, null::text, null::text;
    return;
  end;

  return query select 'ok'::text, v_id, to_char(v_inicio, 'DD/MM/YYYY HH24:MI'), to_char(v_fim, 'DD/MM/YYYY HH24:MI');
end;
$$;

drop function if exists registrar_orcamento(text, text, text, text, text, text);
create or replace function registrar_orcamento(p_session_id text, p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, orcamento_id uuid, veiculo text, valor_total numeric)
language plpgsql
as $$
declare
  v_veiculo text;
  v_valor numeric;
  v_count int;
  v_orcamento_id uuid;
  v_motor text;
  v_ano int;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select count(*) into v_count from veiculos v
  where trim(lower(v.modelo)) = trim(lower(p_modelo))
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v.ano = v_ano
    and (v_motor is null or trim(lower(v.motor)) = trim(lower(v_motor)));

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::uuid, null::text, null::numeric;
    return;
  elsif v_count > 1 then
    return query select 'ambiguo'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select v.modelo || ' ' || v.montadora || ' ' || v.ano::text,
    (v.litros_oleo_cambio + coalesce(v.litros_oleo_limpeza, 0)) * p.preco_litro
      + coalesce(f_ext.preco, 0) + coalesce(f_int.preco, 0) + s.preco_mao_obra
  into v_veiculo, v_valor
  from veiculos v
  join produtos p on p.id = v.produto_oleo_id
  join servicos s on s.id = v.servico_id
  left join filtros f_ext on f_ext.id = v.filtro_externo_id
  left join filtros f_int on f_int.id = v.filtro_interno_id
  where trim(lower(v.modelo)) = trim(lower(p_modelo))
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v.ano = v_ano
    and (v_motor is null or trim(lower(v.motor)) = trim(lower(v_motor)));

  insert into orcamentos (session_id, veiculo, valor_total, status)
  values (p_session_id, v_veiculo, v_valor, 'enviado')
  returning id into v_orcamento_id;

  return query select 'ok'::text, v_orcamento_id, v_veiculo, v_valor;
end;
$$;

drop function if exists registrar_orcamento_motor(text, text, text, text, text, text);
create or replace function registrar_orcamento_motor(p_session_id text, p_modelo text, p_montadora text, p_ano text, p_motor text default null)
returns table(status text, orcamento_id uuid, veiculo text, valor_total numeric)
language plpgsql
as $$
declare
  v_veiculo text;
  v_valor numeric;
  v_count int;
  v_orcamento_id uuid;
  v_motor text;
  v_ano int;
begin
  v_motor := nullif(trim(p_motor), '');
  v_ano := nullif(regexp_replace(coalesce(p_ano, ''), '[^0-9]', '', 'g'), '')::int;

  if v_ano is null then
    return query select 'dados_invalidos'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select count(*) into v_count from veiculos_motor v
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%')
    and v.produto_oleo_motor_id is not null
    and v.servico_motor_id is not null;

  if v_count = 0 then
    return query select 'nao_encontrado'::text, null::uuid, null::text, null::numeric;
    return;
  elsif v_count > 1 then
    return query select 'ambiguo'::text, null::uuid, null::text, null::numeric;
    return;
  end if;

  select v.modelo || ' ' || v.montadora,
    (ceil(v.litros_oleo_motor) * p.preco_litro) + coalesce(f.preco, 0) + s.preco_mao_obra
  into v_veiculo, v_valor
  from veiculos_motor v
  join produtos p on p.id = v.produto_oleo_motor_id
  join servicos s on s.id = v.servico_motor_id
  left join filtros f on f.id = v.filtro_oleo_motor_id
  where regexp_replace(upper(v.modelo), '[^A-Z0-9]', '', 'g') like '%' || regexp_replace(upper(trim(p_modelo)), '[^A-Z0-9]', '', 'g') || '%'
    and trim(lower(v.montadora)) = trim(lower(p_montadora))
    and v_ano between v.ano_inicio and v.ano_fim
    and (v_motor is null or trim(lower(v.motor_descricao)) like '%' || trim(lower(v_motor)) || '%');

  insert into orcamentos (session_id, veiculo, valor_total, status)
  values (p_session_id, v_veiculo, v_valor, 'enviado')
  returning id into v_orcamento_id;

  return query select 'ok'::text, v_orcamento_id, v_veiculo, v_valor;
end;
$$;
