"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { requireNegocioContext } from "@/lib/supabase/context";
import type { SugestaoProdutoMotor } from "@/types/database";

/**
 * Confirma, em lote, o vínculo sugerido (produto de óleo + serviço) para os
 * veículos de motor selecionados. Busca as sugestões de novo no servidor via
 * `sugerir_produtos_motor` — nunca confia em produto/serviço vindos do
 * cliente — e só grava as que tiverem sugestão completa disponível.
 */
export async function confirmarVinculos(veiculoMotorIds: string[]) {
  const ctx = await requireNegocioContext();

  const ids = veiculoMotorIds.filter(Boolean);
  if (ids.length === 0) {
    throw new Error("Selecione ao menos um veículo para vincular.");
  }

  const supabase = createClient();

  const { data: sugestoes, error: erroSugestoes } = await supabase.rpc(
    "sugerir_produtos_motor",
    { p_negocio_id: ctx.effectiveNegocioId }
  );
  if (erroSugestoes) throw new Error(erroSugestoes.message);

  const selecionadas = ((sugestoes ?? []) as SugestaoProdutoMotor[]).filter(
    (s) => ids.includes(s.veiculo_motor_id) && s.produto_sugerido_id && s.servico_sugerido_id
  );

  if (selecionadas.length === 0) {
    throw new Error(
      "Nenhum dos veículos selecionados tem uma sugestão completa de produto e serviço."
    );
  }

  const resultados = await Promise.all(
    selecionadas.map((s) =>
      supabase
        .from("veiculos_motor")
        .update({
          produto_oleo_motor_id: s.produto_sugerido_id,
          servico_motor_id: s.servico_sugerido_id,
        })
        .eq("id", s.veiculo_motor_id)
        .eq("negocio_id", ctx.effectiveNegocioId)
    )
  );

  const comErro = resultados.find((r) => r.error);
  if (comErro?.error) throw new Error(comErro.error.message);

  revalidatePath("/produtos/vincular");
}
