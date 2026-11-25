"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireContext } from "@/lib/supabase/context";

/** Atualiza só o preço do filtro. O bot passa a usar o novo valor no próximo orçamento. */
export async function atualizarPrecoFiltro(filtroId: string, formData: FormData) {
  await requireContext();
  const supabase = createClient();

  const preco = Number(String(formData.get("preco") ?? "").replace(",", "."));
  if (Number.isNaN(preco) || preco <= 0) throw new Error("Preço inválido.");

  const { error } = await supabase.from("filtros").update({ preco }).eq("id", filtroId);

  if (error) throw new Error(error.message);
  revalidatePath("/filtros");
}
