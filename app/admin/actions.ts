"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireAdmin, ADMIN_VIEW_COOKIE } from "@/lib/supabase/context";

export async function criarNegocio(formData: FormData) {
  await requireAdmin();
  const supabase = createClient();

  const nome = String(formData.get("nome") || "").trim();
  const email_contato = String(formData.get("email_contato") || "").trim();
  const plano = String(formData.get("plano") || "trial").trim();

  if (!nome || !email_contato) {
    throw new Error("Nome e e-mail de contato são obrigatórios.");
  }

  const { data, error } = await supabase
    .from("negocios")
    .insert({ nome, email_contato, plano })
    .select("id")
    .single();

  if (error) throw new Error(error.message);

  revalidatePath("/admin/negocios");
  redirect(`/admin/negocios/${data.id}`);
}

export async function atualizarStatusAssinatura(negocioId: string, status: string) {
  await requireAdmin();
  const supabase = createClient();

  const { error } = await supabase
    .from("negocios")
    .update({ status_assinatura: status })
    .eq("id", negocioId);

  if (error) throw new Error(error.message);

  revalidatePath(`/admin/negocios/${negocioId}`);
  revalidatePath("/admin/negocios");
}

export async function atualizarPlano(negocioId: string, plano: string) {
  await requireAdmin();
  const supabase = createClient();

  const { error } = await supabase.from("negocios").update({ plano }).eq("id", negocioId);
  if (error) throw new Error(error.message);

  revalidatePath(`/admin/negocios/${negocioId}`);
  revalidatePath("/admin/negocios");
}

/** Entra em "modo suporte": passa a visualizar a operação de um negócio específico. */
export async function acessarComoSuporte(negocioId: string) {
  await requireAdmin();
  cookies().set(ADMIN_VIEW_COOKIE, negocioId, {
    httpOnly: true,
    sameSite: "lax",
    path: "/",
  });
  redirect("/dashboard");
}

export async function sairDoModoSuporte() {
  cookies().delete(ADMIN_VIEW_COOKIE);
  redirect("/admin/negocios");
}
