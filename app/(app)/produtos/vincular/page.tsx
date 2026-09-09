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
          Sugestão automática de produto (óleo) e serviço para cada veículo de motor cadastrado
        </p>
      </div>

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      {!error &&
        (!sugestoes || sugestoes.length === 0 ? (
          <div className="card p-8 text-center text-sm text-slate-500">
            Nenhum veículo pendente de vínculo por aqui.
          </div>
        ) : (
          <VincularList sugestoes={sugestoes as SugestaoProdutoMotor[]} />
        ))}
    </div>
  );
}
