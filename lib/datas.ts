// Datas do painel sempre no fuso da oficina.
// As páginas são renderizadas no servidor da Vercel, que roda em UTC: sem fixar o fuso,
// um agendamento às 08:00 de Fortaleza (11:00 UTC) aparecia como 11:00 e o "dia" ia de 21:00 a 20:59.
// Fortaleza não tem horário de verão, por isso o deslocamento fixo -03:00 é seguro.

export const FUSO = "America/Fortaleza";
const DESLOCAMENTO = "-03:00";

/** "23/11/2026, 08:00" no horário de Fortaleza. */
export function formatarDataHora(iso: string | null | undefined): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
    timeZone: FUSO,
  });
}

/** Data de hoje em Fortaleza, no formato AAAA-MM-DD. */
export function hojeLocal(): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: FUSO }).format(new Date());
}

/** Início e fim (em ISO/UTC) de um dia AAAA-MM-DD de Fortaleza, para filtrar timestamps no banco. */
export function limitesDoDia(data: string): { inicio: string; fim: string } {
  return {
    inicio: new Date(`${data}T00:00:00${DESLOCAMENTO}`).toISOString(),
    fim: new Date(`${data}T23:59:59.999${DESLOCAMENTO}`).toISOString(),
  };
}
