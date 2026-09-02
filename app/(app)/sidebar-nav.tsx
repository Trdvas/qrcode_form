"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutDashboard, Calendar, Package, type LucideIcon } from "lucide-react";

const NAV_ITEMS: { href: string; label: string; icon: LucideIcon; match: (path: string) => boolean }[] = [
  {
    href: "/dashboard",
    label: "Dashboard",
    icon: LayoutDashboard,
    match: (path) => path === "/dashboard",
  },
  {
    href: "/agendamentos",
    label: "Agendamentos",
    icon: Calendar,
    match: (path) => path.startsWith("/agendamentos"),
  },
  {
    href: "/produtos",
    label: "Produtos e Serviços",
    icon: Package,
    match: (path) => path.startsWith("/produtos") || path.startsWith("/servicos"),
  },
];

export default function SidebarNav() {
  const pathname = usePathname();

  return (
    <nav className="space-y-1 px-3">
      {NAV_ITEMS.map((item) => {
        const ativo = item.match(pathname);
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
              ativo ? "bg-brand-50 text-brand-600" : "text-slate-500 hover:bg-slate-100"
            }`}
          >
            <Icon className="h-4 w-4" strokeWidth={2} />
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
