"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireNegocioContext } from "@/lib/supabase/context";
import type { SugestaoProdutoMotor } from "@/types/database";

export interface ParVinculo {
  veiculoId: string;
  produtoId: string;
}

/**
 * Confirma, em lote, o vínculo de produto (óleo) sugerido para os pares
 * veículo/produto selecionados. Busca as sugestões de novo no servidor via
 * `sugerir_produtos_motor` — nunca confia no par vindo do cliente — e só
 * grava os pares que ainda estiverem entre as sugestões atuais.
 *
 * A function `sugerir_produtos_motor` não sugere serviço; `servico_motor_id`
 * não é tocado por esta ação.
 */
export async function confirmarVinculos(pares: ParVinculo[]) {
  const ctx = await requireNegocioContext();

  const validos = pares.filter((p) => p.veiculoId && p.produtoId);
  if (validos.length === 0) {
    throw new Error("Selecione ao menos um veículo para vincular.");
  }

  const supabase = createClient();

  const { data: sugestoes, error: erroSugestoes } = await supabase.rpc(
    "sugerir_produtos_motor",
    { p_negocio_id: ctx.effectiveNegocioId }
  );
  if (erroSugestoes) throw new Error(erroSugestoes.message);

  const sugestoesValidas = new Set(
    ((sugestoes ?? []) as SugestaoProdutoMotor[]).map((s) => `${s.veiculo_id}:${s.produto_id}`)
  );

  const confirmadas = validos.filter((p) =>
    sugestoesValidas.has(`${p.veiculoId}:${p.produtoId}`)
  );

  if (confirmadas.length === 0) {
    throw new Error("Os pares selecionados não estão mais entre as sugestões atuais.");
  }

  const resultados = await Promise.all(
    confirmadas.map((p) =>
      supabase
        .from("veiculos_motor")
        .update({ produto_oleo_motor_id: p.produtoId })
        .eq("id", p.veiculoId)
        .eq("negocio_id", ctx.effectiveNegocioId)
    )
  );

  const comErro = resultados.find((r) => r.error);
  if (comErro?.error) throw new Error(comErro.error.message);

  revalidatePath("/produtos/vincular");
}
