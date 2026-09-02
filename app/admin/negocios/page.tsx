import Link from "next/link";
import { requireAdmin } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Negocio } from "@/types/database";

const STATUS_BADGE: Record<string, string> = {
  ativo: "bg-green-100 text-green-700",
  trial: "bg-amber-100 text-amber-700",
  inadimplente: "bg-red-100 text-red-700",
  cancelado: "bg-gray-100 text-gray-600",
};

export default async function NegociosPage() {
  await requireAdmin();
  const supabase = createClient();

  const { data: negocios, error } = await supabase
    .from("negocios")
    .select("*")
    .order("criado_em", { ascending: false });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Negócios</h1>
          <p className="text-sm text-gray-500">Todos os negócios cadastrados na plataforma</p>
        </div>
        <Link href="/admin/negocios/novo" className="btn-primary">
          + Novo negócio
        </Link>
      </div>

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[640px]">
          <thead>
            <tr className="border-b border-gray-200 bg-gray-50 text-left text-xs font-semibold uppercase text-gray-500">
              <th className="px-4 py-3">Nome</th>
              <th className="px-4 py-3">E-mail de contato</th>
              <th className="px-4 py-3">Plano</th>
              <th className="px-4 py-3">Assinatura</th>
              <th className="px-4 py-3">Criado em</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {(negocios as Negocio[] | null)?.map((n) => (
              <tr key={n.id} className="border-b border-gray-100">
                <td className="px-4 py-3 text-sm font-medium text-gray-900">{n.nome}</td>
                <td className="px-4 py-3 text-sm text-gray-700">{n.email_contato}</td>
                <td className="px-4 py-3 text-sm text-gray-700 capitalize">{n.plano}</td>
                <td className="px-4 py-3 text-sm">
                  <span
                    className={`badge ${
                      STATUS_BADGE[n.status_assinatura] ?? "bg-gray-100 text-gray-600"
                    }`}
                  >
                    {n.status_assinatura}
                  </span>
                </td>
                <td className="px-4 py-3 text-sm text-gray-500">
                  {new Date(n.criado_em).toLocaleDateString("pt-BR")}
                </td>
                <td className="px-4 py-3 text-right text-sm">
                  <Link
                    href={`/admin/negocios/${n.id}`}
                    className="font-medium text-brand-600 hover:underline"
                  >
                    Ver detalhes
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!negocios || negocios.length === 0) && (
          <p className="px-4 py-8 text-center text-sm text-gray-500">
            Nenhum negócio cadastrado ainda.
          </p>
        )}
      </div>
    </div>
  );
}
