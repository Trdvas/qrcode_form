import { requireAdmin } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Negocio } from "@/types/database";
import { badgeClass, statusAssinaturaTone } from "@/lib/ui/badge";
import PlataformaBadge from "../plataforma-badge";
import StatusSelect from "./status-select";

export default async function AssinaturasPage() {
  await requireAdmin();
  const supabase = createClient();

  const { data: negocios, error } = await supabase
    .from("negocios")
    .select("*")
    .order("nome", { ascending: true });

  return (
    <div className="space-y-6">
      <div>
        <div className="mb-1.5">
          <PlataformaBadge />
        </div>
        <h1 className="text-2xl font-bold text-slate-900">Assinaturas</h1>
        <p className="text-sm text-slate-500">Altere o status de assinatura de cada negócio</p>
      </div>

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[640px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="px-4 py-3">Negócio</th>
              <th className="px-4 py-3">Plano</th>
              <th className="px-4 py-3">Status atual</th>
              <th className="px-4 py-3">Alterar status</th>
            </tr>
          </thead>
          <tbody>
            {(negocios as Negocio[] | null)?.map((n) => (
              <tr key={n.id} className="border-b border-slate-100 transition-colors hover:bg-slate-50">
                <td className="px-4 py-3 text-sm font-medium text-slate-900">{n.nome}</td>
                <td className="px-4 py-3 text-sm text-slate-700 capitalize">{n.plano}</td>
                <td className="px-4 py-3 text-sm">
                  <span className={badgeClass(statusAssinaturaTone(n.status_assinatura))}>
                    {n.status_assinatura}
                  </span>
                </td>
                <td className="px-4 py-3 text-sm">
                  <StatusSelect negocioId={n.id} statusAtual={n.status_assinatura} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!negocios || negocios.length === 0) && (
          <p className="px-4 py-8 text-center text-sm text-slate-500">
            Nenhum negócio cadastrado ainda.
          </p>
        )}
      </div>
    </div>
  );
}
