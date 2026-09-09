-- ============================================================================
-- Vínculo automático de veículos de motor com produtos (óleo) e serviços
-- ============================================================================
--
-- `veiculos_motor` é o catálogo de perfis de motor cadastrados por negócio
-- (marca/modelo + especificação de óleo recomendada), que pode ser vinculado
-- a um produto (óleo) e a um serviço (mão de obra) já cadastrados. A função
-- `sugerir_produtos_motor` sugere, para cada veículo do negócio, o produto e
-- o serviço mais adequados ainda não vinculados corretamente.

create table if not exists veiculos_motor (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references negocios (id) on delete cascade,
  marca text not null,
  modelo text not null,
  especificacao_oleo_recomendada text not null,
  produto_oleo_motor_id uuid references produtos (id) on delete set null,
  servico_motor_id uuid references servicos (id) on delete set null,
  criado_em timestamptz not null default now()
);

create index if not exists idx_veiculos_motor_negocio_id on veiculos_motor (negocio_id);

alter table veiculos_motor enable row level security;

create policy "veiculos_motor_all" on veiculos_motor for all
  using (auth_is_admin_plataforma() or negocio_id = auth_negocio_id())
  with check (auth_is_admin_plataforma() or negocio_id = auth_negocio_id());

-- ----------------------------------------------------------------------------
-- sugerir_produtos_motor(p_negocio_id)
-- ----------------------------------------------------------------------------
-- Para cada veículo do negócio cujo vínculo atual (produto_oleo_motor_id /
-- servico_motor_id) difere do que seria sugerido hoje — incluindo veículos
-- ainda sem nenhum vínculo — retorna o produto e o serviço sugeridos:
--   - produto: o de menor preço/litro cuja especificação contém a
--     especificação de óleo recomendada do veículo;
--   - serviço: o serviço ativo de menor mão de obra cujo nome contenha "óleo".
-- security invoker (padrão do Postgres): as consultas internas respeitam a
-- RLS do usuário chamador, então cada dono de negócio só vê sugestões do seu
-- próprio negocio_id mesmo que informe outro id.
create or replace function sugerir_produtos_motor(p_negocio_id uuid)
returns table (
  veiculo_motor_id uuid,
  marca text,
  modelo text,
  especificacao_oleo_recomendada text,
  produto_atual_id uuid,
  servico_atual_id uuid,
  produto_sugerido_id uuid,
  produto_sugerido_label text,
  servico_sugerido_id uuid,
  servico_sugerido_label text
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    vm.id as veiculo_motor_id,
    vm.marca,
    vm.modelo,
    vm.especificacao_oleo_recomendada,
    vm.produto_oleo_motor_id as produto_atual_id,
    vm.servico_motor_id as servico_atual_id,
    p.id as produto_sugerido_id,
    p.label as produto_sugerido_label,
    s.id as servico_sugerido_id,
    s.nome as servico_sugerido_label
  from veiculos_motor vm
  left join lateral (
    select pr.id, (pr.marca || ' — ' || pr.especificacao) as label
    from produtos pr
    where pr.negocio_id = p_negocio_id
      and pr.especificacao ilike '%' || vm.especificacao_oleo_recomendada || '%'
    order by pr.preco_litro asc
    limit 1
  ) p on true
  left join lateral (
    select se.id, se.nome
    from servicos se
    where se.negocio_id = p_negocio_id
      and se.ativo = true
      and se.nome ilike '%óleo%'
    order by se.preco_mao_obra asc
    limit 1
  ) s on true
  where vm.negocio_id = p_negocio_id
    and (vm.produto_oleo_motor_id is distinct from p.id or vm.servico_motor_id is distinct from s.id)
  order by vm.marca, vm.modelo;
$$;
