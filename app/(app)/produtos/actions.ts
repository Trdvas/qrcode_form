"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireContext } from "@/lib/supabase/context";

function parsePreco(valor: FormDataEntryValue | null): number {
  const n = Number(String(valor ?? "").replace(",", "."));
  if (Number.isNaN(n) || n < 0) throw new Error("Preço inválido.");
  return n;
}

export async function criarProduto(formData: FormData) {
  await requireContext();
  const supabase = createClient();

  const marca = String(formData.get("marca") || "").trim();
  const especificacao = String(formData.get("especificacao") || "").trim();
  const preco_litro = parsePreco(formData.get("preco_litro"));

  if (!marca || !especificacao) throw new Error("Marca e especificação são obrigatórias.");

  const { error } = await supabase.from("produtos").insert({ marca, especificacao, preco_litro });

  if (error) throw new Error(error.message);
  revalidatePath("/produtos");
}

export async function atualizarProduto(produtoId: string, formData: FormData) {
  await requireContext();
  const supabase = createClient();

  const marca = String(formData.get("marca") || "").trim();
  const especificacao = String(formData.get("especificacao") || "").trim();
  const preco_litro = parsePreco(formData.get("preco_litro"));

  if (!marca || !especificacao) throw new Error("Marca e especificação são obrigatórias.");

  const { error } = await supabase
    .from("produtos")
    .update({ marca, especificacao, preco_litro })
    .eq("id", produtoId);

  if (error) throw new Error(error.message);
  revalidatePath("/produtos");
}

export async function removerProduto(produtoId: string) {
  await requireContext();
  const supabase = createClient();

  const { error } = await supabase.from("produtos").delete().eq("id", produtoId);

  if (error) throw new Error(error.message);
  revalidatePath("/produtos");
}
