import { requireNegocioContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Agendamento } from "@/types/database";
import { badgeClass, statusAgendamentoTone } from "@/lib/ui/badge";

const STATUS_OPTIONS = [
  { value: "", label: "Todos os status" },
  { value: "confirmado", label: "Confirmado" },
  { value: "concluido", label: "Concluído" },
  { value: "cancelado", label: "Cancelado" },
];

export default async function AgendamentosPage({
  searchParams,
}: {
  searchParams: { status?: string; data?: string };
}) {
  const ctx = await requireNegocioContext();
  const supabase = createClient();

  const status = searchParams.status || "";
  const data = searchParams.data || "";

  let query = supabase
    .from("agendamentos")
    .select("*")
    .eq("negocio_id", ctx.effectiveNegocioId)
    .order("data_hora_inicio", { ascending: false });

  if (status) query = query.eq("status", status);
  if (data) {
    const inicio = new Date(`${data}T00:00:00`);
    const fim = new Date(`${data}T23:59:59.999`);
    query = query.gte("data_hora_inicio", inicio.toISOString()).lte("data_hora_inicio", fim.toISOString());
  }

  const { data: agendamentos, error } = await query;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Agendamentos</h1>
        <p className="text-sm text-slate-500">Agendamentos criados pelo agente de IA no WhatsApp</p>
      </div>

      <form method="get" className="card flex flex-wrap items-end gap-3 p-4">
        <div>
          <label className="label">Status</label>
          <select name="status" defaultValue={status} className="input">
            {STATUS_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="label">Data</label>
          <input type="date" name="data" defaultValue={data} className="input" />
        </div>
        <button type="submit" className="btn-primary">
          Filtrar
        </button>
        {(status || data) && (
          <a href="/agendamentos" className="btn-secondary">
            Limpar filtros
          </a>
        )}
      </form>

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[560px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="px-4 py-3">Veículo</th>
              <th className="px-4 py-3">Início</th>
              <th className="px-4 py-3">Fim</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Sessão</th>
            </tr>
          </thead>
          <tbody>
            {(agendamentos as Agendamento[] | null)?.map((ag) => (
              <tr key={ag.id} className="border-b border-slate-100 transition-colors hover:bg-slate-50">
                <td className="px-4 py-3 text-sm font-medium text-slate-900">
                  {ag.veiculo || "—"}
                </td>
                <td className="px-4 py-3 text-sm text-slate-700">
                  {new Date(ag.data_hora_inicio).toLocaleString("pt-BR", {
                    dateStyle: "short",
                    timeStyle: "short",
                  })}
                </td>
                <td className="px-4 py-3 text-sm text-slate-700">
                  {new Date(ag.data_hora_fim).toLocaleString("pt-BR", {
                    dateStyle: "short",
                    timeStyle: "short",
                  })}
                </td>
                <td className="px-4 py-3 text-sm">
                  <span className={badgeClass(statusAgendamentoTone(ag.status))}>{ag.status}</span>
                </td>
                <td className="px-4 py-3 text-xs text-slate-400">{ag.session_id}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {(!agendamentos || agendamentos.length === 0) && (
          <p className="px-4 py-8 text-center text-sm text-slate-500">
            Nenhum agendamento encontrado para os filtros selecionados.
          </p>
        )}
      </div>
    </div>
  );
}
