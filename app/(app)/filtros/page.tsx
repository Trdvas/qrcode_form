import { requireContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Filtro } from "@/types/database";
import ProdutosServicosTabs from "../produtos-servicos-tabs";
import FiltrosLista, { type FiltroComCarros } from "./filtros-lista";

type Linha = Filtro & { veiculos_motor: { modelo: string; montadora: string }[] | null };

export default async function FiltrosPage() {
  await requireContext();
  const supabase = createClient();

  // Só filtros de óleo do motor (os de câmbio têm descrição vazia e ficam de fora).
  const { data, error } = await supabase
    .from("filtros")
    .select("id, codigo, descricao, preco, criado_em, veiculos_motor(modelo, montadora)")
    .ilike("descricao", "%óleo do motor%")
    .order("codigo", { ascending: true });

  const filtros: FiltroComCarros[] = ((data as Linha[] | null) ?? []).map((f) => {
    const carros = Array.from(
      new Set((f.veiculos_motor ?? []).map((v) => `${v.modelo} ${v.montadora}`.trim())),
    ).sort((a, b) => a.localeCompare(b, "pt-BR"));
    return {
      id: f.id,
      codigo: f.codigo,
      preco: Number(f.preco),
      motorizacoes: f.veiculos_motor?.length ?? 0,
      carros,
    };
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Produtos e Serviços</h1>
        <p className="text-sm text-slate-500">
          Filtros de óleo do motor. O preço alterado aqui vale no próximo orçamento do agente.
        </p>
      </div>

      <ProdutosServicosTabs ativa="filtros" />

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      <FiltrosLista filtros={filtros} />
    </div>
  );
}
