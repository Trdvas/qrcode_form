/**
 * Lógica de cor única para badges de status em todo o painel:
 * verde = positivo, cinza = neutro/inativo, vermelho = negativo/cancelado.
 */
export type BadgeTone = "success" | "neutral" | "danger" | "info";

const TONE_CLASSES: Record<BadgeTone, string> = {
  success: "badge bg-green-100 text-green-700",
  neutral: "badge bg-slate-100 text-slate-600",
  danger: "badge bg-red-100 text-red-700",
  info: "badge bg-brand-100 text-brand-700",
};

export function badgeClass(tone: BadgeTone): string {
  return TONE_CLASSES[tone];
}

export function statusAgendamentoTone(status: string): BadgeTone {
  if (status === "confirmado") return "success";
  if (status === "cancelado") return "danger";
  return "neutral"; // concluido e outros
}

export function statusAssinaturaTone(status: string): BadgeTone {
  if (status === "ativo") return "success";
  if (status === "cancelado" || status === "inadimplente") return "danger";
  return "neutral"; // trial
}

export function ativoTone(ativo: boolean): BadgeTone {
  return ativo ? "success" : "neutral";
}
