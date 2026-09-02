"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireNegocioContext } from "@/lib/supabase/context";

function parsePreco(valor: FormDataEntryValue | null): number {
  const n = Number(String(valor ?? "").replace(",", "."));
  if (Number.isNaN(n) || n < 0) throw new Error("Preço inválido.");
  return n;
}

export async function criarServico(formData: FormData) {
  const ctx = await requireNegocioContext();
  const supabase = createClient();

  const nome = String(formData.get("nome") || "").trim();
  const preco_mao_obra = parsePreco(formData.get("preco_mao_obra"));

  if (!nome) throw new Error("Nome do serviço é obrigatório.");

  const { error } = await supabase
    .from("servicos")
    .insert({ negocio_id: ctx.effectiveNegocioId, nome, preco_mao_obra });

  if (error) throw new Error(error.message);
  revalidatePath("/servicos");
}

export async function atualizarServico(servicoId: string, formData: FormData) {
  const ctx = await requireNegocioContext();
  const supabase = createClient();

  const nome = String(formData.get("nome") || "").trim();
  const preco_mao_obra = parsePreco(formData.get("preco_mao_obra"));

  if (!nome) throw new Error("Nome do serviço é obrigatório.");

  const { error } = await supabase
    .from("servicos")
    .update({ nome, preco_mao_obra })
    .eq("id", servicoId)
    .eq("negocio_id", ctx.effectiveNegocioId);

  if (error) throw new Error(error.message);
  revalidatePath("/servicos");
}

export async function alternarAtivoServico(servicoId: string, ativo: boolean) {
  const ctx = await requireNegocioContext();
  const supabase = createClient();

  const { error } = await supabase
    .from("servicos")
    .update({ ativo })
    .eq("id", servicoId)
    .eq("negocio_id", ctx.effectiveNegocioId);

  if (error) throw new Error(error.message);
  revalidatePath("/servicos");
}

export async function removerServico(servicoId: string) {
  const ctx = await requireNegocioContext();
  const supabase = createClient();

  const { error } = await supabase
    .from("servicos")
    .delete()
    .eq("id", servicoId)
    .eq("negocio_id", ctx.effectiveNegocioId);

  if (error) throw new Error(error.message);
  revalidatePath("/servicos");
}
