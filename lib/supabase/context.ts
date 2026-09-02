import "server-only";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Role } from "@/types/database";

export const ADMIN_VIEW_COOKIE = "admin_view_negocio_id";

export interface RequestContext {
  userId: string;
  email: string | null;
  role: Role;
  /** negocio_id "real" do usuário logado (null para admin da plataforma) */
  negocioId: string | null;
  isAdmin: boolean;
  /**
   * negocio_id efetivo a usar nas consultas: o próprio negócio do dono,
   * ou — quando um admin está em "modo suporte" — o negócio selecionado.
   */
  effectiveNegocioId: string | null;
  /** true quando um admin está visualizando um negócio de terceiros */
  isSupportView: boolean;
}

/**
 * Lê o contexto de autenticação resolvido pelo middleware (headers x-user-id,
 * x-user-role, x-negocio-id) evitando uma nova consulta a `usuarios_perfil`
 * em cada Server Component/Server Action.
 */
export async function getRequestContext(): Promise<RequestContext | null> {
  const h = headers();
  const userId = h.get("x-user-id");
  const role = h.get("x-user-role") as Role | null;

  if (!userId || !role) return null;

  const negocioId = h.get("x-negocio-id") || null;
  const isAdmin = role === "admin_plataforma";

  const viewCookie = cookies().get(ADMIN_VIEW_COOKIE)?.value || null;
  const isSupportView = isAdmin && !!viewCookie;

  return {
    userId,
    email: h.get("x-user-email"),
    role,
    negocioId,
    isAdmin,
    effectiveNegocioId: isAdmin ? viewCookie : negocioId,
    isSupportView,
  };
}

/** Exige um contexto autenticado; redireciona para /login caso contrário. */
export async function requireContext(): Promise<RequestContext> {
  const ctx = await getRequestContext();
  if (!ctx) redirect("/login");
  return ctx;
}

/**
 * Exige um dono de negócio com negocio_id resolvido (inclui admin em modo
 * suporte, que passa a operar sobre o negocio_id selecionado).
 */
export async function requireNegocioContext(): Promise<
  RequestContext & { effectiveNegocioId: string }
> {
  const ctx = await requireContext();
  if (!ctx.effectiveNegocioId) {
    // Admin sem negócio selecionado tentando acessar área operacional
    redirect("/admin/negocios");
  }
  return ctx as RequestContext & { effectiveNegocioId: string };
}

export async function requireAdmin(): Promise<RequestContext> {
  const ctx = await requireContext();
  if (!ctx.isAdmin) redirect("/dashboard");
  return ctx;
}

export async function getNegocioNome(negocioId: string): Promise<string | null> {
  const supabase = createClient();
  const { data } = await supabase
    .from("negocios")
    .select("nome")
    .eq("id", negocioId)
    .maybeSingle();
  return data?.nome ?? null;
}
