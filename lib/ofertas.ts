import type { OfertaRetornoPainel } from "@/types/database";

export function formatBRL(v: number | string | null | undefined): string {
  if (v === null || v === undefined || v === "") return "—";
  return Number(v).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

function cartao(valor: number | null, parcelas: number | null): string {
  const p = parcelas && parcelas > 1 ? ` em até ${parcelas}x` : "";
  return `${formatBRL(valor)} no cartão${p}`;
}

/**
 * Preço da oferta em uma linha.
 * Se o cliente fechou durante a oferta, mostra a opção que ele escolheu; senão, a opção citada na mensagem
 * ("a partir de" para quem só tinha cotado).
 */
export function textoOferta(o: OfertaRetornoPainel): string {
  if (o.fechou_avista !== null) {
    return `${o.fechou_marca ?? ""}: ${formatBRL(o.fechou_avista)} à vista ou ${cartao(o.fechou_cartao, o.fechou_parcelas)}`.trim();
  }
  const prefixo = o.origem === "cotacao" ? "a partir de " : "";
  return `${prefixo}${formatBRL(o.base_avista)} à vista ou ${cartao(o.base_cartao, o.base_parcelas)}`;
}

export function servicoOferta(o: OfertaRetornoPainel): string {
  return o.tipo === "cambio" ? "Óleo do câmbio" : "Óleo do motor";
}
