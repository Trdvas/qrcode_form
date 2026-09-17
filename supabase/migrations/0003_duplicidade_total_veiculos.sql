-- ============================================================================
-- Ajusta a checagem de duplicidade do catálogo de veículos: em vez de
-- bloquear qualquer sobreposição de modelo/montadora/motor/ano (o que barra
-- cadastros legítimos que só diferem em outros campos, como litragem de
-- óleo), passa a bloquear apenas DUPLICIDADE TOTAL — quando todos os campos
-- do cadastro são idênticos entre si.
-- ============================================================================

alter table veiculos_motor drop constraint if exists veiculos_motor_sem_sobreposicao;
drop index if exists veiculos_sem_duplicata;

-- Sentinela usado no lugar de NULL nas colunas de referência (uuid), para
-- que duas linhas com o mesmo campo opcional vazio ainda sejam comparadas
-- como iguais (NULL nunca é igual a NULL numa unique constraint comum).
create unique index if not exists veiculos_duplicidade_total on veiculos (
  lower(modelo),
  lower(montadora),
  ano,
  lower(coalesce(motor, '')),
  lower(tipo_cambio),
  litros_oleo_cambio,
  coalesce(litros_oleo_limpeza, 0),
  coalesce(produto_oleo_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(servico_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(filtro_externo_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(filtro_interno_id, '00000000-0000-0000-0000-000000000000'::uuid)
);

create unique index if not exists veiculos_motor_duplicidade_total on veiculos_motor (
  lower(modelo),
  lower(montadora),
  ano_inicio,
  ano_fim,
  lower(coalesce(motor_descricao, '')),
  litros_oleo_motor,
  coalesce(produto_oleo_motor_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(servico_motor_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(filtro_oleo_motor_id, '00000000-0000-0000-0000-000000000000'::uuid),
  lower(coalesce(viscosidade_recomendada, ''))
);
