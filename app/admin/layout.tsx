import { requireAdmin } from "@/lib/supabase/context";
import { signOut } from "@/app/auth/actions";
import AdminSidebarNav from "./sidebar-nav";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const ctx = await requireAdmin();

  return (
    <div className="flex min-h-screen">
      <aside className="hidden w-60 shrink-0 border-r border-slate-200 bg-slate-900 text-white sm:block">
        <div className="px-5 py-5">
          <p className="text-lg font-bold">Painel de Gestão</p>
          <p className="mt-0.5 text-xs text-slate-400">Administração da plataforma</p>
        </div>
        <AdminSidebarNav />
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-slate-200 bg-white px-4 py-3 sm:px-6">
          <p className="text-sm font-semibold text-slate-900 sm:hidden">Admin</p>
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
  );
}
