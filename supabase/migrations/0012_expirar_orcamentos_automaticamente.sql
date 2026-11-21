-- ============================================================================
-- Expira automaticamente orçamentos "enviado" sem confirmação após 30 dias.
--
-- Requer a extensão pg_cron. No Supabase, se o create extension abaixo
-- falhar por permissão, habilite antes em Database → Extensions → pg_cron
-- (interface do projeto), depois rode este arquivo de novo.
-- ============================================================================

create extension if not exists pg_cron;

create or replace function expirar_orcamentos_antigos()
returns void
language sql
as $$
  update orcamentos
  set status = 'expirado'
  where status = 'enviado'
    and data_criacao < now() - interval '30 days';
$$;

select cron.unschedule(jobid)
from cron.job
where jobname = 'expirar_orcamentos_antigos';

select cron.schedule(
  'expirar_orcamentos_antigos',
  '0 3 * * *',
  $$select expirar_orcamentos_antigos()$$
);
