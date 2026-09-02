import Link from "next/link";
import { requireNegocioContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Agendamento } from "@/types/database";

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
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-sm text-gray-500">Resumo da operação de hoje</p>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="card p-5">
          <p className="text-sm text-gray-500">Agendamentos hoje</p>
          <p className="mt-2 text-3xl font-bold text-gray-900">{agendamentosHoje ?? 0}</p>
        </div>
        <div className="card p-5">
          <p className="text-sm text-gray-500">Orçamentos enviados (7 dias)</p>
          <p className="mt-2 text-3xl font-bold text-gray-900">{orcamentosRecentes ?? 0}</p>
        </div>
        <div className="card flex flex-col justify-center gap-2 p-5">
          <Link href="/produtos" className="btn-secondary w-full justify-start">
            Gerenciar produtos
          </Link>
          <Link href="/servicos" className="btn-secondary w-full justify-start">
            Gerenciar serviços
          </Link>
        </div>
      </div>

      <div className="card">
        <div className="flex items-center justify-between border-b border-gray-200 px-5 py-3">
          <h2 className="font-semibold text-gray-900">Próximos agendamentos confirmados</h2>
          <Link href="/agendamentos" className="text-sm font-medium text-brand-600 hover:underline">
            Ver todos
          </Link>
        </div>
        {!proximosAgendamentos || proximosAgendamentos.length === 0 ? (
          <p className="px-5 py-8 text-center text-sm text-gray-500">
            Nenhum agendamento confirmado nos próximos dias.
          </p>
        ) : (
          <ul className="divide-y divide-gray-100">
            {proximosAgendamentos.map((ag) => (
              <li key={ag.id} className="flex items-center justify-between px-5 py-3 text-sm">
                <div>
                  <p className="font-medium text-gray-900">{ag.veiculo || "Veículo não informado"}</p>
                  <p className="text-gray-500">
                    {new Date(ag.data_hora_inicio).toLocaleString("pt-BR", {
                      dateStyle: "short",
                      timeStyle: "short",
                    })}
                  </p>
                </div>
                <span className="badge bg-green-100 text-green-700">{ag.status}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
