-- ============================================================================
-- orcamentos.status era texto livre, sem nenhuma trava -- diferente de
-- agendamentos.status, que só aceita os valores realmente usados. Hoje só
-- existe um valor gravado em qualquer lugar do código ('enviado', tanto no
-- default da coluna quanto nas funções registrar_orcamento/registrar_orcamento_motor),
-- então o CHECK abaixo só formaliza o que já é verdade na prática.
-- ============================================================================

alter table orcamentos
  add constraint orcamentos_status_valido check (status in ('enviado'));
