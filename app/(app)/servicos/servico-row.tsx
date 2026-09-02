"use client";

import { useState, useTransition } from "react";
import type { Servico } from "@/types/database";
import { atualizarServico, alternarAtivoServico, removerServico } from "./actions";
import { badgeClass, ativoTone } from "@/lib/ui/badge";

function formatBRL(v: number) {
  return v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

export default function ServicoRow({ servico }: { servico: Servico }) {
  const [editando, setEditando] = useState(false);
  const [pending, startTransition] = useTransition();
  const [erro, setErro] = useState<string | null>(null);

  async function handleSubmit(formData: FormData) {
    setErro(null);
    try {
      await atualizarServico(servico.id, formData);
      setEditando(false);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro ao salvar.");
    }
  }

  function handleRemover() {
    if (!confirm(`Remover o serviço "${servico.nome}"?`)) return;
    startTransition(() => removerServico(servico.id));
  }

  function handleToggle() {
    startTransition(() => alternarAtivoServico(servico.id, !servico.ativo));
  }

  if (editando) {
    return (
      <tr className="border-b border-slate-100 bg-slate-50">
        <td colSpan={4} className="px-4 py-3">
          <form action={handleSubmit} className="flex flex-wrap items-end gap-3">
            <div>
              <label className="label">Nome</label>
              <input name="nome" defaultValue={servico.nome} required className="input" />
            </div>
            <div>
              <label className="label">Mão de obra (R$)</label>
              <input
                name="preco_mao_obra"
                type="number"
                step="0.01"
                min="0"
                defaultValue={servico.preco_mao_obra}
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
      <td className="px-4 py-3 text-sm font-medium text-slate-900">{servico.nome}</td>
      <td className="px-4 py-3 text-sm text-slate-700">{formatBRL(servico.preco_mao_obra)}</td>
      <td className="px-4 py-3 text-sm">
        <button onClick={handleToggle} disabled={pending}>
          <span className={badgeClass(ativoTone(servico.ativo))}>
            {servico.ativo ? "Ativo" : "Inativo"}
          </span>
        </button>
      </td>
      <td className="px-4 py-3 text-right text-sm">
        <button
          onClick={() => setEditando(true)}
          className="mr-3 font-medium text-brand-600 hover:underline"
        >
          Editar
        </button>
        <button
          onClick={handleRemover}
          disabled={pending}
          className="font-medium text-red-600 hover:underline disabled:opacity-50"
        >
          Remover
        </button>
      </td>
    </tr>
  );
}
