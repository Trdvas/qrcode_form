/**
 * Lógica de cor única para badges de status em todo o painel:
 * verde = positivo, cinza = neutro/inativo, vermelho = negativo/cancelado.
 */
export type BadgeTone = "success" | "neutral" | "danger" | "info";

const TONE_CLASSES: Record<BadgeTone, string> = {
  success: "badge bg-green-50 text-green-600",
  neutral: "badge bg-slate-100 text-slate-500",
  danger: "badge bg-red-50 text-red-600",
  info: "badge bg-brand-50 text-brand-600",
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
