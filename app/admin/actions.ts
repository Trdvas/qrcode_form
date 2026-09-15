"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireAdmin } from "@/lib/supabase/context";

export async function atualizarNegocio(formData: FormData) {
  await requireAdmin();
  const supabase = createClient();

  const nome = String(formData.get("nome") || "").trim();
  const email_contato = String(formData.get("email_contato") || "").trim();

  if (!nome || !email_contato) {
    throw new Error("Nome e e-mail de contato são obrigatórios.");
  }

  const { error } = await supabase.from("negocio").update({ nome, email_contato }).eq("id", true);

  if (error) throw new Error(error.message);

  revalidatePath("/admin");
  revalidatePath("/dashboard");
}
