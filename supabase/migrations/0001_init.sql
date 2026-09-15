-- ============================================================================
-- Painel de Gestão (Negócio Único) — schema inicial
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- Tabelas
-- ----------------------------------------------------------------------------

-- `negocio` é uma tabela singleton (sempre uma única linha, id fixo em
-- `true`) com os dados do único negócio administrado por este painel.
create table if not exists negocio (
  id boolean primary key default true,
  nome text not null default '',
  email_contato text not null default '',
  criado_em timestamptz not null default now(),
  constraint negocio_singleton check (id)
);

insert into negocio (id) values (true) on conflict (id) do nothing;

create table if not exists usuarios_perfil (
  id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('admin', 'operador')),
  criado_em timestamptz not null default now()
);

create table if not exists produtos (
  id uuid primary key default gen_random_uuid(),
  marca text not null,
  especificacao text not null,
  preco_litro numeric(10, 2) not null check (preco_litro >= 0),
  criado_em timestamptz not null default now()
);

create table if not exists servicos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  preco_mao_obra numeric(10, 2) not null check (preco_mao_obra >= 0),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table if not exists agendamentos (
  id uuid primary key default gen_random_uuid(),
  session_id text not null,
  veiculo text,
  data_hora_inicio timestamptz not null,
  data_hora_fim timestamptz not null,
  status text not null default 'confirmado' check (status in ('confirmado', 'concluido', 'cancelado')),
  criado_em timestamptz not null default now(),
  constraint agendamentos_periodo_valido check (data_hora_fim > data_hora_inicio)
);

create table if not exists orcamentos (
  id uuid primary key default gen_random_uuid(),
  session_id text not null,
  veiculo text,
  valor_total numeric(10, 2),
  status text not null default 'enviado',
  data_criacao timestamptz not null default now(),
  data_ultimo_contato timestamptz
);

-- ----------------------------------------------------------------------------
-- Índices
-- ----------------------------------------------------------------------------

create index if not exists idx_agendamentos_data on agendamentos (data_hora_inicio);
create index if not exists idx_agendamentos_status on agendamentos (status);
create index if not exists idx_orcamentos_data on orcamentos (data_criacao);

-- ----------------------------------------------------------------------------
-- Helpers para as policies de RLS
-- ----------------------------------------------------------------------------

-- security definer evita recursão de RLS ao consultar usuarios_perfil dentro
-- das próprias policies de usuarios_perfil.
create or replace function auth_has_perfil()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from usuarios_perfil where id = auth.uid());
$$;

create or replace function auth_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from usuarios_perfil
    where id = auth.uid() and role = 'admin'
  );
$$;

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------

alter table negocio enable row level security;
alter table usuarios_perfil enable row level security;
alter table produtos enable row level security;
alter table servicos enable row level security;
alter table agendamentos enable row level security;
alter table orcamentos enable row level security;

-- negocio: qualquer usuário com perfil pode ver os dados do negócio;
-- apenas admin pode editá-los.
create policy "negocio_select" on negocio for select
  using (auth_has_perfil());

create policy "negocio_update_admin" on negocio for update
  using (auth_is_admin())
  with check (auth_is_admin());

-- usuarios_perfil: cada usuário vê o próprio perfil; admin vê e gerencia todos.
create policy "usuarios_perfil_select" on usuarios_perfil for select
  using (auth_is_admin() or id = auth.uid());

create policy "usuarios_perfil_insert_admin" on usuarios_perfil for insert
  with check (auth_is_admin());

create policy "usuarios_perfil_update_admin" on usuarios_perfil for update
  using (auth_is_admin())
  with check (auth_is_admin());

create policy "usuarios_perfil_delete_admin" on usuarios_perfil for delete
  using (auth_is_admin());

-- produtos / servicos / agendamentos / orcamentos: qualquer usuário com
-- perfil (admin ou operador) do negócio único acessa livremente.
create policy "produtos_all" on produtos for all
  using (auth_has_perfil())
  with check (auth_has_perfil());

create policy "servicos_all" on servicos for all
  using (auth_has_perfil())
  with check (auth_has_perfil());

create policy "agendamentos_all" on agendamentos for all
  using (auth_has_perfil())
  with check (auth_has_perfil());

create policy "orcamentos_all" on orcamentos for all
  using (auth_has_perfil())
  with check (auth_has_perfil());
