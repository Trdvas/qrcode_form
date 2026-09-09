"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireNegocioContext } from "@/lib/supabase/context";
import type { SugestaoProdutoMotor } from "@/types/database";

export interface ParVinculo {
  veiculoId: string;
  produtoId: string;
  /** Escolhido manualmente pelo usuário — nunca inferido automaticamente. */
  servicoId: string;
}

/**
 * Confirma, em lote, o vínculo de produto (óleo, sugerido) + serviço
 * (escolhido manualmente) para os pares selecionados. Produto e serviço são
 * obrigatórios: se qualquer par estiver incompleto, nada é gravado.
 *
 * Revalida no servidor antes de escrever — nunca confia no cliente:
 * o produto contra `sugerir_produtos_motor`, o serviço contra os serviços
 * ativos do negócio.
 */
export async function confirmarVinculos(pares: ParVinculo[]) {
  const ctx = await requireNegocioContext();

  if (pares.length === 0) {
    throw new Error("Selecione ao menos um veículo para vincular.");
  }

  const incompleto = pares.find((p) => !p.veiculoId || !p.produtoId || !p.servicoId);
  if (incompleto) {
    throw new Error(
      "Produto e serviço são obrigatórios para todos os veículos selecionados — nada foi vinculado."
    );
  }

  const supabase = createClient();

  const [{ data: sugestoes, error: erroSugestoes }, { data: servicosAtivos, error: erroServicos }] =
    await Promise.all([
      supabase.rpc("sugerir_produtos_motor", { p_negocio_id: ctx.effectiveNegocioId }),
      supabase
        .from("servicos")
        .select("id")
        .eq("negocio_id", ctx.effectiveNegocioId)
        .eq("ativo", true),
    ]);
  if (erroSugestoes) throw new Error(erroSugestoes.message);
  if (erroServicos) throw new Error(erroServicos.message);

  const produtosValidos = new Set(
    ((sugestoes ?? []) as SugestaoProdutoMotor[]).map((s) => `${s.veiculo_id}:${s.produto_id}`)
  );
  const servicosValidos = new Set((servicosAtivos ?? []).map((s) => s.id));

  const invalido = pares.find(
    (p) => !produtosValidos.has(`${p.veiculoId}:${p.produtoId}`) || !servicosValidos.has(p.servicoId)
  );
  if (invalido) {
    throw new Error(
      "Um dos pares selecionados não é mais válido (produto fora das sugestões atuais, ou serviço não está mais ativo) — nada foi vinculado."
    );
  }

  const resultados = await Promise.all(
    pares.map((p) =>
      supabase
        .from("veiculos_motor")
        .update({ produto_oleo_motor_id: p.produtoId, servico_motor_id: p.servicoId })
        .eq("id", p.veiculoId)
        .eq("negocio_id", ctx.effectiveNegocioId)
    )
  );

  const comErro = resultados.find((r) => r.error);
  if (comErro?.error) throw new Error(comErro.error.message);

  revalidatePath("/produtos/vincular");
}
