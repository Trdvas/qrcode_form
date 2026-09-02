import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

const PUBLIC_PATHS = ["/login", "/auth/callback"];

function isPublicPath(pathname: string) {
  return (
    PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`)) ||
    pathname.startsWith("/_next") ||
    pathname.startsWith("/favicon") ||
    pathname === "/api/health"
  );
}

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // Renova a sessão (necessário em toda requisição para Server Components).
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;

  if (!user) {
    if (isPublicPath(pathname)) return response;
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("redirectTo", pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Usuário autenticado tentando acessar /login → manda pra área correta.
  if (pathname === "/login") {
    return NextResponse.redirect(new URL("/", request.url));
  }

  // Resolve o perfil (role + negocio_id) do usuário logado nesta requisição
  // e propaga via headers para Server Components/Server Actions consumirem
  // sem precisar de uma nova consulta ao banco.
  const { data: perfil } = await supabase
    .from("usuarios_perfil")
    .select("role, negocio_id")
    .eq("id", user.id)
    .maybeSingle();

  if (!perfil) {
    // Usuário existe no Auth mas ainda não tem perfil provisionado.
    if (pathname !== "/sem-acesso") {
      return NextResponse.redirect(new URL("/sem-acesso", request.url));
    }
    return response;
  }

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-user-id", user.id);
  requestHeaders.set("x-user-email", user.email ?? "");
  requestHeaders.set("x-user-role", perfil.role);
  requestHeaders.set("x-negocio-id", perfil.negocio_id ?? "");

  response = NextResponse.next({ request: { headers: requestHeaders } });
  // Reaplica os cookies de sessão (potencialmente renovados) na resposta final.
  request.cookies.getAll().forEach((cookie) => {
    response.cookies.set(cookie.name, cookie.value);
  });

  // Guarda de rotas por papel.
  const isAdminRoute = pathname.startsWith("/admin");
  const isAppRoute = ["/dashboard", "/produtos", "/servicos", "/agendamentos"].some(
    (p) => pathname === p || pathname.startsWith(`${p}/`)
  );

  if (isAdminRoute && perfil.role !== "admin_plataforma") {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  if (isAppRoute && perfil.role === "admin_plataforma") {
    // Admin só acessa a área operacional em "modo suporte" (negócio selecionado).
    const viewingNegocioId = request.cookies.get("admin_view_negocio_id")?.value;
    if (!viewingNegocioId) {
      return NextResponse.redirect(new URL("/admin/negocios", request.url));
    }
  }

  if (pathname === "/") {
    const dest = perfil.role === "admin_plataforma" ? "/admin/negocios" : "/dashboard";
    return NextResponse.redirect(new URL(dest, request.url));
  }

  return response;
}

export const config = {
  matcher: [
    /*
     * Executa em tudo exceto assets estáticos do Next.
     */
    "/((?!_next/static|_next/image|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
