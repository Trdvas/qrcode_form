import { requireContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Filtro } from "@/types/database";
import ProdutosServicosTabs from "../produtos-servicos-tabs";
import FiltrosLista, { type Aplicacao, type FiltroComCarros } from "./filtros-lista";

type VeiculoMotor = {
  modelo: string;
  montadora: string;
  motor_descricao: string | null;
  ano_inicio: number | null;
  ano_fim: number | null;
};
type Linha = Filtro & { veiculos_motor: VeiculoMotor[] | null };

/** Remove linhas repetidas (mesmo carro/motor/anos) e ordena por montadora, modelo, motor e ano. */
function montarAplicacao(veiculos: VeiculoMotor[]): Aplicacao[] {
  const vistos = new Map<string, Aplicacao>();
  for (const v of veiculos) {
    const a: Aplicacao = {
      montadora: v.montadora.trim(),
      modelo: v.modelo.trim(),
      motor: (v.motor_descricao ?? "").trim(),
      anoInicio: v.ano_inicio,
      anoFim: v.ano_fim,
    };
    const chave = [a.montadora, a.modelo, a.motor, a.anoInicio, a.anoFim].join("|").toLowerCase();
    if (!vistos.has(chave)) vistos.set(chave, a);
  }
  return Array.from(vistos.values()).sort(
    (x, y) =>
      x.montadora.localeCompare(y.montadora, "pt-BR") ||
      x.modelo.localeCompare(y.modelo, "pt-BR") ||
      x.motor.localeCompare(y.motor, "pt-BR") ||
      (x.anoInicio ?? 0) - (y.anoInicio ?? 0),
  );
}

export default async function FiltrosPage() {
  await requireContext();
  const supabase = createClient();

  // Só filtros de óleo do motor (os de câmbio têm descrição vazia e ficam de fora).
  const { data, error } = await supabase
    .from("filtros")
    .select(
      "id, codigo, descricao, preco, criado_em, veiculos_motor(modelo, montadora, motor_descricao, ano_inicio, ano_fim)",
    )
    .ilike("descricao", "%óleo do motor%")
    .order("codigo", { ascending: true });

  const filtros: FiltroComCarros[] = ((data as Linha[] | null) ?? []).map((f) => ({
    id: f.id,
    codigo: f.codigo,
    preco: Number(f.preco),
    aplicacao: montarAplicacao(f.veiculos_motor ?? []),
  }));

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
