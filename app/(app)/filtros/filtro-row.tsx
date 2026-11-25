"use client";

import { useState } from "react";
import { Pencil } from "lucide-react";
import { atualizarPrecoFiltro } from "./actions";
import type { FiltroComCarros } from "./filtros-lista";

function formatBRL(v: number) {
  return v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

export default function FiltroRow({ filtro }: { filtro: FiltroComCarros }) {
  const [editando, setEditando] = useState(false);
  const [aberto, setAberto] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function handleSubmit(formData: FormData) {
    setErro(null);
    try {
      await atualizarPrecoFiltro(filtro.id, formData);
      setEditando(false);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro ao salvar.");
    }
  }

  const resumo =
    filtro.carros.length === 0
      ? null
      : filtro.carros.slice(0, 3).join(", ") + (filtro.carros.length > 3 ? "…" : "");

  return (
    <tr className="border-b border-slate-100 align-top transition-colors hover:bg-slate-50">
      <td className="px-4 py-3 text-sm font-medium text-slate-900">{filtro.codigo}</td>
      <td className="px-4 py-3 text-sm text-slate-700">
        {resumo === null ? (
          <span className="text-slate-400">Nenhum carro ligado</span>
        ) : (
          <div>
            <button
              type="button"
              onClick={() => setAberto((a) => !a)}
              className="text-left hover:text-brand-600"
              title="Ver todos os carros"
            >
              {aberto ? filtro.carros.join(", ") : resumo}
            </button>
            <p className="text-xs text-slate-400">{filtro.motorizacoes} motorizações</p>
          </div>
        )}
      </td>
      <td className="px-4 py-3 text-sm text-slate-700">
        {editando ? (
          <form action={handleSubmit} className="flex items-center gap-2">
            <input
              name="preco"
              type="number"
              step="0.01"
              min="0.01"
              defaultValue={filtro.preco}
              required
              autoFocus
              className="input w-28"
            />
            <button type="submit" className="btn-primary">
              Salvar
            </button>
            <button type="button" className="btn-secondary" onClick={() => setEditando(false)}>
              Cancelar
            </button>
          </form>
        ) : (
          formatBRL(filtro.preco)
        )}
        {erro && <p className="mt-1 text-xs text-red-600">{erro}</p>}
      </td>
      <td className="px-4 py-3 text-right text-sm">
        {!editando && (
          <button
            onClick={() => setEditando(true)}
            aria-label="Editar preço"
            className="rounded-md p-1.5 text-slate-400 transition-colors hover:bg-brand-50 hover:text-brand-600"
          >
            <Pencil className="h-4 w-4" strokeWidth={2} />
          </button>
        )}
      </td>
    </tr>
  );
}
