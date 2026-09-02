import { requireNegocioContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Servico } from "@/types/database";
import ProdutosServicosTabs from "../produtos-servicos-tabs";
import ServicoRow from "./servico-row";
import NovoServicoForm from "./novo-servico-form";

export default async function ServicosPage() {
  const ctx = await requireNegocioContext();
  const supabase = createClient();

  const { data: servicos, error } = await supabase
    .from("servicos")
    .select("*")
    .eq("negocio_id", ctx.effectiveNegocioId)
    .order("nome", { ascending: true });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Produtos e Serviços</h1>
        <p className="text-sm text-slate-500">Mão de obra oferecida pela oficina</p>
      </div>

      <div className="flex items-center justify-between">
        <ProdutosServicosTabs ativa="servicos" />
        <NovoServicoForm />
      </div>

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[560px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="px-4 py-3">Nome</th>
              <th className="px-4 py-3">Mão de obra</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {(servicos as Servico[] | null)?.map((servico) => (
              <ServicoRow key={servico.id} servico={servico} />
            ))}
          </tbody>
        </table>
        {(!servicos || servicos.length === 0) && (
          <p className="px-4 py-8 text-center text-sm text-slate-500">
            Nenhum serviço cadastrado ainda.
          </p>
        )}
      </div>
    </div>
  );
}
