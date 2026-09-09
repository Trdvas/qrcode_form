import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { requireNegocioContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { SugestaoProdutoMotor } from "@/types/database";
import VincularList from "./vincular-list";

export default async function VincularVeiculosPage() {
  const ctx = await requireNegocioContext();
  const supabase = createClient();

  const { data: sugestoes, error } = await supabase.rpc("sugerir_produtos_motor", {
    p_negocio_id: ctx.effectiveNegocioId,
  });

  return (
    <div className="space-y-6">
      <div>
        <Link
          href="/produtos"
          className="mb-2 inline-flex items-center gap-1 text-sm font-medium text-brand-600 hover:underline"
        >
          <ArrowLeft className="h-4 w-4" strokeWidth={2} />
          Produtos e Serviços
        </Link>
        <h1 className="text-2xl font-bold text-slate-900">Vincular Veículos</h1>
        <p className="text-sm text-slate-500">
          Sugestão automática de produto (óleo) para cada veículo de motor ainda sem vínculo, a
          partir da viscosidade recomendada
        </p>
        <p className="mt-1 text-xs text-slate-400">
          O vínculo de serviço não é sugerido automaticamente aqui — só o produto.
        </p>
      </div>

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      {!error &&
        (!sugestoes || sugestoes.length === 0 ? (
          <div className="card p-8 text-center text-sm text-slate-500">
            Nenhuma sugestão de vínculo por aqui — todos os veículos já têm produto vinculado, ou
            nenhum produto cadastrado combina com a viscosidade recomendada.
          </div>
        ) : (
          <VincularList sugestoes={sugestoes as SugestaoProdutoMotor[]} />
        ))}
    </div>
  );
}
