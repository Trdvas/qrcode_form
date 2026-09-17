-- ============================================================================
-- Resolve ambiguidade por litragem em veiculos_motor: quando dois cadastros
-- têm mesma motorização (modelo/montadora/motor_descricao), faixa de ano
-- sobreposta, e a litragem de óleo difere em até 300ml (0.3L), considera-se
-- que é o mesmo veículo cadastrado mais de uma vez — mantém apenas o mais
-- atual (maior ano_fim).
--
-- Isso não dá pra fazer só com uma constraint (que só bloqueia, não decide
-- qual registro manter), por isso é um trigger.
-- ============================================================================

create or replace function veiculos_motor_resolver_duplicidade()
returns trigger
language plpgsql
as $$
declare
  v_max_ano_fim int;
begin
  select max(v.ano_fim) into v_max_ano_fim
  from veiculos_motor v
  where v.id <> new.id
    and lower(v.modelo) = lower(new.modelo)
    and lower(v.montadora) = lower(new.montadora)
    and lower(coalesce(v.motor_descricao, '')) = lower(coalesce(new.motor_descricao, ''))
    and int4range(v.ano_inicio, v.ano_fim + 1) && int4range(new.ano_inicio, new.ano_fim + 1)
    and abs(v.litros_oleo_motor - new.litros_oleo_motor) <= 0.3;

  if v_max_ano_fim is null then
    -- nenhum cadastro conflitante (mesma motorização + ano sobreposto +
    -- litragem próxima) — segue normalmente.
    return new;
  end if;

  if new.ano_fim > v_max_ano_fim then
    -- o novo cadastro é mais atual: remove os conflitantes mais antigos.
    delete from veiculos_motor v
    where v.id <> new.id
      and lower(v.modelo) = lower(new.modelo)
      and lower(v.montadora) = lower(new.montadora)
      and lower(coalesce(v.motor_descricao, '')) = lower(coalesce(new.motor_descricao, ''))
      and int4range(v.ano_inicio, v.ano_fim + 1) && int4range(new.ano_inicio, new.ano_fim + 1)
      and abs(v.litros_oleo_motor - new.litros_oleo_motor) <= 0.3;
    return new;
  else
    -- já existe um cadastro igual ou mais atual: descarta este
    -- insert/update (silenciosamente, sem erro).
    return null;
  end if;
end;
$$;

drop trigger if exists trg_veiculos_motor_resolver_duplicidade on veiculos_motor;
create trigger trg_veiculos_motor_resolver_duplicidade
  before insert or update of modelo, montadora, motor_descricao, ano_inicio, ano_fim, litros_oleo_motor
  on veiculos_motor
  for each row
  execute function veiculos_motor_resolver_duplicidade();
