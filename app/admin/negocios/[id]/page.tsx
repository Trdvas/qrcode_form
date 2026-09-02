import { notFound } from "next/navigation";
import { requireAdmin } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import { acessarComoSuporte } from "@/app/admin/actions";
import StatusAssinaturaForm from "./status-assinatura-form";

export default async function NegocioDetalhePage({ params }: { params: { id: string } }) {
  await requireAdmin();
  const supabase = createClient();

  const { data: negocio } = await supabase
    .from("negocios")
    .select("*")
    .eq("id", params.id)
    .maybeSingle();

  if (!negocio) notFound();

  const [{ count: totalProdutos }, { count: totalServicos }, { count: totalAgendamentos }] =
    await Promise.all([
      supabase
        .from("produtos")
        .select("id", { count: "exact", head: true })
        .eq("negocio_id", negocio.id),
      supabase
        .from("servicos")
        .select("id", { count: "exact", head: true })
        .eq("negocio_id", negocio.id),
      supabase
        .from("agendamentos")
        .select("id", { count: "exact", head: true })
        .eq("negocio_id", negocio.id),
    ]);

  return (
    <div className="max-w-2xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">{negocio.nome}</h1>
        <p className="text-sm text-gray-500">{negocio.email_contato}</p>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div className="card p-4 text-center">
          <p className="text-2xl font-bold text-gray-900">{totalProdutos ?? 0}</p>
          <p className="text-xs text-gray-500">Produtos</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-2xl font-bold text-gray-900">{totalServicos ?? 0}</p>
          <p className="text-xs text-gray-500">Serviços</p>
        </div>
        <div className="card p-4 text-center">
          <p className="text-2xl font-bold text-gray-900">{totalAgendamentos ?? 0}</p>
          <p className="text-xs text-gray-500">Agendamentos</p>
        </div>
      </div>

      <div className="card space-y-4 p-6">
        <h2 className="font-semibold text-gray-900">Assinatura</h2>
        <StatusAssinaturaForm
          negocioId={negocio.id}
          plano={negocio.plano}
          statusAssinatura={negocio.status_assinatura}
        />
      </div>

      <div className="card space-y-3 p-6">
        <h2 className="font-semibold text-gray-900">Suporte</h2>
        <p className="text-sm text-gray-500">
          Acesse a operação deste negócio como se fosse o próprio dono, para fins de suporte.
        </p>
        <form action={acessarComoSuporte.bind(null, negocio.id)}>
          <button type="submit" className="btn-secondary">
            Acessar como suporte
          </button>
        </form>
      </div>
    </div>
  );
}
