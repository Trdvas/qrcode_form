import Link from "next/link";
import { Calendar, FileText, ArrowRight, Package } from "lucide-react";
import { requireNegocioContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Agendamento } from "@/types/database";
import { badgeClass, statusAgendamentoTone } from "@/lib/ui/badge";

function inicioDoDia() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.toISOString();
}
function fimDoDia() {
  const d = new Date();
  d.setHours(23, 59, 59, 999);
  return d.toISOString();
}

export default async function DashboardPage() {
  const ctx = await requireNegocioContext();
  const supabase = createClient();
  const negocioId = ctx.effectiveNegocioId;

  const seteDiasAtras = new Date();
  seteDiasAtras.setDate(seteDiasAtras.getDate() - 7);

  const agendamentosHojeQuery = supabase
    .from("agendamentos")
    .select("id", { count: "exact", head: true })
    .eq("negocio_id", negocioId)
    .gte("data_hora_inicio", inicioDoDia())
    .lte("data_hora_inicio", fimDoDia());

  const orcamentosRecentesQuery = supabase
    .from("orcamentos")
    .select("id", { count: "exact", head: true })
    .eq("negocio_id", negocioId)
    .gte("data_criacao", seteDiasAtras.toISOString());

  const proximosAgendamentosQuery = supabase
    .from("agendamentos")
    .select("*")
    .eq("negocio_id", negocioId)
    .eq("status", "confirmado")
    .gte("data_hora_inicio", new Date().toISOString())
    .order("data_hora_inicio", { ascending: true })
    .limit(5);

  const [{ count: agendamentosHoje }, { count: orcamentosRecentes }] = await Promise.all([
    agendamentosHojeQuery,
    orcamentosRecentesQuery,
  ]);
  const { data: proximosAgendamentosData } = await proximosAgendamentosQuery;
  const proximosAgendamentos = proximosAgendamentosData as Agendamento[] | null;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Dashboard</h1>
        <p className="text-sm text-slate-500">Resumo da operação de hoje</p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="card flex items-start justify-between bg-brand-50 p-5">
          <div>
            <p className="text-sm text-slate-500">Agendamentos hoje</p>
            <p className="mt-2 text-3xl font-bold text-brand-600">{agendamentosHoje ?? 0}</p>
          </div>
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-brand-600">
            <Calendar className="h-5 w-5" strokeWidth={2} />
          </span>
        </div>
        <div className="card flex items-start justify-between bg-green-50 p-5">
          <div>
            <p className="text-sm text-slate-500">Orçamentos enviados (7 dias)</p>
            <p className="mt-2 text-3xl font-bold text-green-600">{orcamentosRecentes ?? 0}</p>
          </div>
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-green-600">
            <FileText className="h-5 w-5" strokeWidth={2} />
          </span>
        </div>
      </div>

      <Link
        href="/produtos"
        className="btn-primary h-14 w-full justify-between px-6 text-base font-semibold"
      >
        <span className="flex items-center gap-3">
          <Package className="h-5 w-5" strokeWidth={2} />
          Gerenciar Produtos e Serviços
        </span>
        <ArrowRight className="h-5 w-5" strokeWidth={2} />
      </Link>

      <div className="card">
        <div className="flex items-center justify-between border-b border-slate-200 px-5 py-3">
          <h2 className="font-semibold text-slate-900">Próximos agendamentos confirmados</h2>
          <Link href="/agendamentos" className="text-sm font-medium text-brand-600 hover:underline">
            Ver todos
          </Link>
        </div>
        {!proximosAgendamentos || proximosAgendamentos.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-slate-500">
            Nenhum agendamento confirmado nos próximos dias.
          </p>
        ) : (
          <ul className="divide-y divide-slate-100">
            {proximosAgendamentos.map((ag) => (
              <li key={ag.id} className="flex items-center justify-between px-5 py-3 text-sm">
                <div>
                  <p className="font-medium text-slate-900">{ag.veiculo || "Veículo não informado"}</p>
                  <p className="font-medium text-brand-600">
                    {new Date(ag.data_hora_inicio).toLocaleString("pt-BR", {
                      dateStyle: "short",
                      timeStyle: "short",
                    })}
                  </p>
                </div>
                <span className={badgeClass(statusAgendamentoTone(ag.status))}>{ag.status}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
