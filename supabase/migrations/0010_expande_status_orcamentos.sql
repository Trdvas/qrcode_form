-- ============================================================================
-- Amplia os valores aceitos em orcamentos.status.
-- ============================================================================

alter table orcamentos drop constraint if exists orcamentos_status_valido;

alter table orcamentos
  add constraint orcamentos_status_valido
  check (status in ('enviado', 'convertido_em_agendamento', 'expirado'));
