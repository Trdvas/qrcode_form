import Link from "next/link";

/**
 * Navegação em formato de abas entre /produtos e /servicos. Continuam sendo
 * duas rotas independentes — isto é só o visual de "abas" pedido no design.
 */
export default function ProdutosServicosTabs({ ativa }: { ativa: "produtos" | "servicos" }) {
  return (
    <div className="inline-flex gap-1 rounded-lg bg-slate-100 p-1">
      <Link
        href="/produtos"
        className={`rounded-md px-4 py-1.5 text-sm font-medium transition-colors ${
          ativa === "produtos" ? "bg-white text-brand-600 shadow-sm" : "text-slate-500 hover:text-slate-700"
        }`}
      >
        Produtos
      </Link>
      <Link
        href="/servicos"
        className={`rounded-md px-4 py-1.5 text-sm font-medium transition-colors ${
          ativa === "servicos" ? "bg-white text-brand-600 shadow-sm" : "text-slate-500 hover:text-slate-700"
        }`}
      >
        Serviços
      </Link>
    </div>
  );
}
