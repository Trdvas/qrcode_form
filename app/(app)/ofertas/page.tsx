import { requireContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { OfertaRetornoPainel } from "@/types/database";
import { badgeClass } from "@/lib/ui/badge";
import { formatarDataHora } from "@/lib/datas";
import { servicoOferta, textoOferta } from "@/lib/ofertas";

const FILTROS = [
  { value: "", label: "Ativas" },
  { value: "todas", label: "Todas" },
];

function Resultado({ o }: { o: OfertaRetornoPainel }) {
  if (o.agendamento_id) {
    return (
      <span className={badgeClass("success")}>
        Agendou {formatarDataHora(o.agendamento_inicio)}
      </span>
    );
  }
  if (o.orcamento_id) return <span className={badgeClass("info")}>Fechou (sem agendar)</span>;
  return <span className="text-sm text-slate-400">—</span>;
}

export default async function OfertasPage({ searchParams }: { searchParams: { ver?: string } }) {
  await requireContext();
  const supabase = createClient();
  const todas = searchParams.ver === "todas";

  let query = supabase
    .from("ofertas_retorno_painel")
    .select("*")
    .order("enviado_em", { ascending: false })
    .limit(200);
  if (!todas) query = query.eq("ativa", true);

  const { data, error } = await query;
  const ofertas = (data as OfertaRetornoPainel[] | null) ?? [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Ofertas de retorno</h1>
        <p className="text-sm text-slate-500">
          Enviadas pelo bot no retorno de orçamento (seg a sáb, 10h): 20% de desconto no óleo à vista ou 10% no
          óleo no cartão. Filtro e mão de obra sem desconto. Se o cliente fechar enquanto a oferta vale, cobre o
          preço desta tela.
        </p>
      </div>

      <div className="card flex flex-wrap items-end gap-6 p-4">
        <div>
          <p className="label">Mostrar</p>
          <div className="inline-flex gap-1 rounded-lg bg-slate-100 p-1">
            {FILTROS.map((opt) => {
              const ativo = (opt.value === "todas") === todas;
              return (
                <a
                  key={opt.value}
                  href={opt.value ? `/ofertas?ver=${opt.value}` : "/ofertas"}
                  className={`rounded-md px-4 py-1.5 text-sm font-medium transition-colors ${
                    ativo ? "bg-white text-brand-600 shadow-sm" : "text-slate-500 hover:text-slate-700"
                  }`}
                >
                  {opt.label}
                </a>
              );
            })}
          </div>
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[760px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="px-4 py-3">Carro</th>
              <th className="px-4 py-3">Preço da oferta</th>
              <th className="px-4 py-3">Enviada em</th>
              <th className="px-4 py-3">Válida até</th>
              <th className="px-4 py-3">Resultado</th>
              <th className="px-4 py-3">Sessão</th>
            </tr>
          </thead>
          <tbody>
            {ofertas.map((o) => (
              <tr key={o.id} className="border-b border-slate-100 transition-colors hover:bg-slate-50">
                <td className="px-4 py-3 text-sm">
                  <p className="font-medium text-slate-900">{o.carro || "—"}</p>
                  <p className="text-xs text-slate-500">
                    {servicoOferta(o)} · {o.origem === "cotacao" ? "só tinha cotado" : "tinha escolhido opção"}
                  </p>
                </td>
                <td className="px-4 py-3 text-sm font-medium text-green-700">{textoOferta(o)}</td>
                <td className="px-4 py-3 text-sm text-slate-700">{formatarDataHora(o.enviado_em)}</td>
                <td className="px-4 py-3 text-sm">
                  <p className="text-slate-700">{formatarDataHora(o.valido_ate)}</p>
                  <span className={badgeClass(o.ativa ? "success" : "neutral")}>{o.ativa ? "Ativa" : "Vencida"}</span>
                </td>
                <td className="px-4 py-3 text-sm">
                  <Resultado o={o} />
                </td>
                <td className="px-4 py-3 text-xs text-slate-400">{o.session_id}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {ofertas.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-slate-500">
            {todas ? "Nenhuma oferta de retorno enviada ainda." : "Nenhuma oferta de retorno ativa agora."}
          </p>
        )}
      </div>
    </div>
  );
}
