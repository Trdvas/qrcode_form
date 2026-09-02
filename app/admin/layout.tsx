import Link from "next/link";
import { requireAdmin } from "@/lib/supabase/context";
import { signOut } from "@/app/auth/actions";

const NAV_ITEMS = [{ href: "/admin/negocios", label: "Negócios" }];

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const ctx = await requireAdmin();

  return (
    <div className="flex min-h-screen">
      <aside className="hidden w-60 shrink-0 border-r border-gray-200 bg-gray-900 text-white sm:block">
        <div className="px-5 py-5">
          <p className="text-lg font-bold">Painel de Gestão</p>
          <p className="mt-0.5 text-xs text-gray-400">Administração da plataforma</p>
        </div>
        <nav className="space-y-1 px-3">
          {NAV_ITEMS.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="block rounded-md px-3 py-2 text-sm font-medium text-gray-200 hover:bg-gray-800"
            >
              {item.label}
            </Link>
          ))}
        </nav>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-gray-200 bg-white px-4 py-3 sm:px-6">
          <p className="text-sm font-semibold text-gray-900 sm:hidden">Admin</p>
          <div className="ml-auto flex items-center gap-3">
            <span className="hidden text-sm text-gray-500 sm:inline">{ctx.email}</span>
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
