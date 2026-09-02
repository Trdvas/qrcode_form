-- ============================================================================
-- Painel de Gestão (Multi-Negócios) — schema inicial
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- Tabelas
-- ----------------------------------------------------------------------------

create table if not exists negocios (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  email_contato text not null,
  plano text not null default 'trial',
  status_assinatura text not null default 'ativo',
  criado_em timestamptz not null default now()
);

create table if not exists usuarios_perfil (
  id uuid primary key references auth.users (id) on delete cascade,
  negocio_id uuid references negocios (id) on delete set null,
  role text not null check (role in ('dono_negocio', 'admin_plataforma')),
  criado_em timestamptz not null default now()
);

create table if not exists produtos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios (id) on delete cascade,
  marca text not null,
  especificacao text not null,
  preco_litro numeric(10, 2) not null check (preco_litro >= 0),
  criado_em timestamptz not null default now()
);

create table if not exists servicos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios (id) on delete cascade,
  nome text not null,
  preco_mao_obra numeric(10, 2) not null check (preco_mao_obra >= 0),
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table if not exists agendamentos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios (id) on delete cascade,
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
  negocio_id uuid not null references negocios (id) on delete cascade,
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

create index if not exists idx_usuarios_perfil_negocio_id on usuarios_perfil (negocio_id);
create index if not exists idx_produtos_negocio_id on produtos (negocio_id);
create index if not exists idx_servicos_negocio_id on servicos (negocio_id);
create index if not exists idx_agendamentos_negocio_id on agendamentos (negocio_id);
create index if not exists idx_agendamentos_negocio_data on agendamentos (negocio_id, data_hora_inicio);
create index if not exists idx_agendamentos_status on agendamentos (negocio_id, status);
create index if not exists idx_orcamentos_negocio_id on orcamentos (negocio_id);
create index if not exists idx_orcamentos_negocio_data on orcamentos (negocio_id, data_criacao);

-- ----------------------------------------------------------------------------
-- Helpers para as policies de RLS
-- ----------------------------------------------------------------------------

-- security definer evita recursão de RLS ao consultar usuarios_perfil dentro
-- das próprias policies de usuarios_perfil / negocios.
create or replace function auth_negocio_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select negocio_id from usuarios_perfil where id = auth.uid();
$$;

create or replace function auth_is_admin_plataforma()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from usuarios_perfil
    where id = auth.uid() and role = 'admin_plataforma'
  );
$$;

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------

alter table negocios enable row level security;
alter table usuarios_perfil enable row level security;
alter table produtos enable row level security;
alter table servicos enable row level security;
alter table agendamentos enable row level security;
alter table orcamentos enable row level security;

-- negocios: dono vê/edita apenas o próprio negócio; admin vê/edita todos.
create policy "negocios_select" on negocios for select
  using (auth_is_admin_plataforma() or id = auth_negocio_id());

create policy "negocios_update" on negocios for update
  using (auth_is_admin_plataforma() or id = auth_negocio_id())
  with check (auth_is_admin_plataforma() or id = auth_negocio_id());

create policy "negocios_insert_admin" on negocios for insert
  with check (auth_is_admin_plataforma());

create policy "negocios_delete_admin" on negocios for delete
  using (auth_is_admin_plataforma());

-- usuarios_perfil: cada usuário vê o próprio perfil; admin vê todos.
create policy "usuarios_perfil_select" on usuarios_perfil for select
  using (auth_is_admin_plataforma() or id = auth.uid());

create policy "usuarios_perfil_insert_admin" on usuarios_perfil for insert
  with check (auth_is_admin_plataforma());

create policy "usuarios_perfil_update_admin" on usuarios_perfil for update
  using (auth_is_admin_plataforma())
  with check (auth_is_admin_plataforma());

create policy "usuarios_perfil_delete_admin" on usuarios_perfil for delete
  using (auth_is_admin_plataforma());

-- produtos / servicos / agendamentos / orcamentos: policy padrão
-- dono_negocio só acessa negocio_id = auth_negocio_id(); admin acessa tudo.
create policy "produtos_all" on produtos for all
  using (auth_is_admin_plataforma() or negocio_id = auth_negocio_id())
  with check (auth_is_admin_plataforma() or negocio_id = auth_negocio_id());

create policy "servicos_all" on servicos for all
  using (auth_is_admin_plataforma() or negocio_id = auth_negocio_id())
  with check (auth_is_admin_plataforma() or negocio_id = auth_negocio_id());

create policy "agendamentos_all" on agendamentos for all
  using (auth_is_admin_plataforma() or negocio_id = auth_negocio_id())
  with check (auth_is_admin_plataforma() or negocio_id = auth_negocio_id());

create policy "orcamentos_all" on orcamentos for all
  using (auth_is_admin_plataforma() or negocio_id = auth_negocio_id())
  with check (auth_is_admin_plataforma() or negocio_id = auth_negocio_id());

-- ----------------------------------------------------------------------------
-- E-mail de boas-vindas ao cadastrar um negócio novo
-- ----------------------------------------------------------------------------
-- Dispara a Edge Function `welcome-email` via pg_net sempre que uma linha é
-- inserida em `negocios`. Requer a extensão pg_net e as configurações abaixo
-- (rodar uma vez por projeto, com a service role key da Edge Function):
--
--   alter database postgres set app.settings.supabase_url = 'https://SEU-PROJETO.supabase.co';
--   alter database postgres set app.settings.service_role_key = 'SUA_SERVICE_ROLE_KEY';
--
-- (No Supabase Studio, isso também pode ser feito via Vault + secrets.)

create extension if not exists pg_net;

create or replace function notificar_negocio_criado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  supabase_url text := current_setting('app.settings.supabase_url', true);
  service_key text := current_setting('app.settings.service_role_key', true);
begin
  if supabase_url is not null and service_key is not null then
    perform net.http_post(
      url := supabase_url || '/functions/v1/welcome-email',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body := jsonb_build_object(
        'negocio_id', new.id,
        'nome', new.nome,
        'email_contato', new.email_contato
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_negocio_criado on negocios;
create trigger trg_negocio_criado
  after insert on negocios
  for each row
  execute function notificar_negocio_criado();
