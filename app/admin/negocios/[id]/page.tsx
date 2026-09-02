import { notFound } from "next/navigation";
import { Package, Wrench, Calendar, LifeBuoy } from "lucide-react";
import { requireAdmin } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import { acessarComoSuporte } from "@/app/admin/actions";
import { badgeClass, statusAssinaturaTone } from "@/lib/ui/badge";
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
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{negocio.nome}</h1>
          <p className="text-sm text-slate-500">{negocio.email_contato}</p>
        </div>
        <span className={badgeClass(statusAssinaturaTone(negocio.status_assinatura))}>
          {negocio.status_assinatura}
        </span>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div className="card flex flex-col items-center gap-1 p-4 text-center">
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-brand-50 text-brand-600">
            <Package className="h-4 w-4" strokeWidth={2} />
          </span>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalProdutos ?? 0}</p>
          <p className="text-xs text-slate-500">Produtos</p>
        </div>
        <div className="card flex flex-col items-center gap-1 p-4 text-center">
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-brand-50 text-brand-600">
            <Wrench className="h-4 w-4" strokeWidth={2} />
          </span>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalServicos ?? 0}</p>
          <p className="text-xs text-slate-500">Serviços</p>
        </div>
        <div className="card flex flex-col items-center gap-1 p-4 text-center">
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-brand-50 text-brand-600">
            <Calendar className="h-4 w-4" strokeWidth={2} />
          </span>
          <p className="mt-1 text-2xl font-bold text-slate-900">{totalAgendamentos ?? 0}</p>
          <p className="text-xs text-slate-500">Agendamentos</p>
        </div>
      </div>

      <div className="card space-y-4 p-6">
        <h2 className="font-semibold text-slate-900">Assinatura</h2>
        <StatusAssinaturaForm
          negocioId={negocio.id}
          plano={negocio.plano}
          statusAssinatura={negocio.status_assinatura}
        />
      </div>

      <div className="card space-y-3 p-6">
        <h2 className="font-semibold text-slate-900">Suporte</h2>
        <p className="text-sm text-slate-500">
          Acesse a operação deste negócio como se fosse o próprio dono, para fins de suporte.
        </p>
        <form action={acessarComoSuporte.bind(null, negocio.id)}>
          <button type="submit" className="btn-secondary">
            <LifeBuoy className="h-4 w-4" strokeWidth={2} />
            Acessar como suporte
          </button>
        </form>
      </div>
    </div>
  );
}
