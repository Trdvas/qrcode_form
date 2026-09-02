import { requireNegocioContext, getNegocioNome } from "@/lib/supabase/context";
import { signOut } from "@/app/auth/actions";
import { sairDoModoSuporte } from "@/app/admin/actions";
import SidebarNav from "./sidebar-nav";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const ctx = await requireNegocioContext();
  const negocioNome = await getNegocioNome(ctx.effectiveNegocioId);

  return (
    <div className="min-h-screen">
      {ctx.isSupportView && (
        <div className="flex items-center justify-between gap-4 bg-amber-500 px-4 py-2 text-sm text-white">
          <span>
            Modo suporte — visualizando <strong>{negocioNome ?? "negócio"}</strong> como
            administrador da plataforma.
          </span>
          <form action={sairDoModoSuporte}>
            <button type="submit" className="underline underline-offset-2">
              Sair do modo suporte
            </button>
          </form>
        </div>
      )}

      <div className="flex min-h-screen">
        <aside className="hidden w-60 shrink-0 border-r border-slate-200 bg-white sm:block">
          <div className="px-5 py-5">
            <p className="text-lg font-bold text-slate-900">Painel de Gestão</p>
            <p className="mt-0.5 truncate text-xs text-slate-500">{negocioNome}</p>
          </div>
          <SidebarNav />
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <header className="flex items-center justify-between border-b border-slate-200 bg-white px-4 py-3 sm:px-6">
            <p className="text-sm text-slate-500 sm:hidden">{negocioNome}</p>
            <div className="ml-auto flex items-center gap-3">
              <span className="hidden text-sm text-slate-500 sm:inline">{ctx.email}</span>
              <form action={signOut}>
                <button type="submit" className="btn-secondary">
                  Sair
                </button>
              </form>
            </div>
          </header>
          <main className="flex-1 px-4 py-6 sm:px-6">{children}</main>
        </div>
      </div>
    </div>
  );
}
