"use client";

import { useState, useTransition } from "react";
import { Pencil, Trash2 } from "lucide-react";
import type { Produto } from "@/types/database";
import { atualizarProduto, removerProduto } from "./actions";

function formatBRL(v: number) {
  return v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

export default function ProdutoRow({ produto }: { produto: Produto }) {
  const [editando, setEditando] = useState(false);
  const [pending, startTransition] = useTransition();
  const [erro, setErro] = useState<string | null>(null);

  async function handleSubmit(formData: FormData) {
    setErro(null);
    try {
      await atualizarProduto(produto.id, formData);
      setEditando(false);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro ao salvar.");
    }
  }

  function handleRemover() {
    if (!confirm(`Remover o produto "${produto.marca} ${produto.especificacao}"?`)) return;
    startTransition(() => removerProduto(produto.id));
  }

  if (editando) {
    return (
      <tr className="border-b border-slate-100 bg-slate-50">
        <td colSpan={4} className="px-4 py-3">
          <form action={handleSubmit} className="flex flex-wrap items-end gap-3">
            <div>
              <label className="label">Marca</label>
              <input name="marca" defaultValue={produto.marca} required className="input" />
            </div>
            <div>
              <label className="label">Especificação</label>
              <input
                name="especificacao"
                defaultValue={produto.especificacao}
                required
                className="input"
              />
            </div>
            <div>
              <label className="label">Preço/litro</label>
              <input
                name="preco_litro"
                type="number"
                step="0.01"
                min="0"
                defaultValue={produto.preco_litro}
                required
                className="input w-32"
              />
            </div>
            <div className="flex gap-2">
              <button type="submit" className="btn-primary">
                Salvar
              </button>
              <button type="button" className="btn-secondary" onClick={() => setEditando(false)}>
                Cancelar
              </button>
            </div>
          </form>
          {erro && <p className="mt-2 text-sm text-red-600">{erro}</p>}
        </td>
      </tr>
    );
  }

  return (
    <tr className="border-b border-slate-100 transition-colors hover:bg-slate-50">
      <td className="px-4 py-3 text-sm font-medium text-slate-900">{produto.marca}</td>
      <td className="px-4 py-3 text-sm text-slate-700">{produto.especificacao}</td>
      <td className="px-4 py-3 text-sm text-slate-700">{formatBRL(produto.preco_litro)}</td>
      <td className="px-4 py-3 text-right text-sm">
        <div className="flex items-center justify-end gap-1">
          <button
            onClick={() => setEditando(true)}
            aria-label="Editar"
            className="rounded-md p-1.5 text-slate-400 transition-colors hover:bg-brand-50 hover:text-brand-600"
          >
            <Pencil className="h-4 w-4" strokeWidth={2} />
          </button>
          <button
            onClick={handleRemover}
            disabled={pending}
            aria-label="Remover"
            className="rounded-md p-1.5 text-slate-400 transition-colors hover:bg-red-50 hover:text-red-600 disabled:opacity-50"
          >
            <Trash2 className="h-4 w-4" strokeWidth={2} />
          </button>
        </div>
      </td>
    </tr>
  );
}
