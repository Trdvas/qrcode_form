import "server-only";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Role } from "@/types/database";

export interface RequestContext {
  userId: string;
  email: string | null;
  role: Role;
  isAdmin: boolean;
}

/**
 * Lê o contexto de autenticação resolvido pelo middleware (headers x-user-id,
 * x-user-role) evitando uma nova consulta a `usuarios_perfil` em cada Server
 * Component/Server Action.
 */
export async function getRequestContext(): Promise<RequestContext | null> {
  const h = headers();
  const userId = h.get("x-user-id");
  const role = h.get("x-user-role") as Role | null;

  if (!userId || !role) return null;

  return {
    userId,
    email: h.get("x-user-email"),
    role,
    isAdmin: role === "admin",
  };
}

/** Exige um contexto autenticado (com perfil); redireciona para /login caso contrário. */
export async function requireContext(): Promise<RequestContext> {
  const ctx = await getRequestContext();
  if (!ctx) redirect("/login");
  return ctx;
}

export async function requireAdmin(): Promise<RequestContext> {
  const ctx = await requireContext();
  if (!ctx.isAdmin) redirect("/dashboard");
  return ctx;
}

/** Nome do negócio único administrado por este painel. */
export async function getNegocioNome(): Promise<string | null> {
  const supabase = createClient();
  const { data } = await supabase.from("negocio").select("nome").eq("id", true).maybeSingle();
  return data?.nome || null;
}
