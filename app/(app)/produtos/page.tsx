import Link from "next/link";
import { Wand2 } from "lucide-react";
import { requireNegocioContext } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Produto } from "@/types/database";
import ProdutosServicosTabs from "../produtos-servicos-tabs";
import ProdutoRow from "./produto-row";
import NovoProdutoForm from "./novo-produto-form";

export default async function ProdutosPage() {
  const ctx = await requireNegocioContext();
  const supabase = createClient();

  const { data: produtos, error } = await supabase
    .from("produtos")
    .select("*")
    .eq("negocio_id", ctx.effectiveNegocioId)
    .order("marca", { ascending: true });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Produtos e Serviços</h1>
        <p className="text-sm text-slate-500">Óleos e produtos usados nos orçamentos do agente</p>
      </div>

      <div className="flex items-center justify-between">
        <ProdutosServicosTabs ativa="produtos" />
        <div className="flex items-center gap-2">
          <Link href="/produtos/vincular" className="btn-secondary">
            <Wand2 className="h-4 w-4" strokeWidth={2} />
            Vincular veículos
          </Link>
          <NovoProdutoForm />
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error.message}</p>}

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[560px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="px-4 py-3">Marca</th>
              <th className="px-4 py-3">Especificação</th>
              <th className="px-4 py-3">Preço/litro</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {(produtos as Produto[] | null)?.map((produto) => (
              <ProdutoRow key={produto.id} produto={produto} />
            ))}
          </tbody>
        </table>
        {(!produtos || produtos.length === 0) && (
          <p className="px-4 py-8 text-center text-sm text-slate-500">
            Nenhum produto cadastrado ainda.
          </p>
        )}
      </div>
    </div>
  );
}
