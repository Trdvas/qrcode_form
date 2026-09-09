"use client";

import { useMemo, useState, useTransition } from "react";
import { CheckCircle2 } from "lucide-react";
import type { SugestaoProdutoMotor } from "@/types/database";
import { confirmarVinculos } from "./actions";

export default function VincularList({ sugestoes }: { sugestoes: SugestaoProdutoMotor[] }) {
  const [selecionados, setSelecionados] = useState<Set<string>>(new Set());
  const [pending, startTransition] = useTransition();
  const [erro, setErro] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState<string | null>(null);

  const selecionaveis = useMemo(
    () => sugestoes.filter((s) => s.produto_sugerido_id && s.servico_sugerido_id),
    [sugestoes]
  );
  const todosSelecionados =
    selecionaveis.length > 0 && selecionaveis.every((s) => selecionados.has(s.veiculo_motor_id));

  function alternar(id: string) {
    setSelecionados((atual) => {
      const novo = new Set(atual);
      if (novo.has(id)) novo.delete(id);
      else novo.add(id);
      return novo;
    });
  }

  function alternarTodos() {
    setSelecionados((atual) => {
      if (todosSelecionados) return new Set();
      return new Set(selecionaveis.map((s) => s.veiculo_motor_id));
    });
  }

  function handleConfirmar() {
    setErro(null);
    setSucesso(null);
    const ids = Array.from(selecionados);
    startTransition(async () => {
      try {
        await confirmarVinculos(ids);
        setSucesso(`${ids.length} veículo(s) vinculado(s) com sucesso.`);
        setSelecionados(new Set());
      } catch (e) {
        setErro(e instanceof Error ? e.message : "Erro ao confirmar o vínculo.");
      }
    });
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <label className="flex items-center gap-2 text-sm font-medium text-slate-700">
          <input
            type="checkbox"
            className="h-4 w-4 rounded border-slate-300"
            checked={todosSelecionados}
            onChange={alternarTodos}
            disabled={selecionaveis.length === 0}
          />
          Selecionar todos ({selecionaveis.length})
        </label>
        <button
          type="button"
          className="btn-success"
          disabled={selecionados.size === 0 || pending}
          onClick={handleConfirmar}
        >
          <CheckCircle2 className="h-4 w-4" strokeWidth={2} />
          {pending ? "Vinculando..." : `Confirmar vínculo${selecionados.size > 1 ? "s" : ""}`}
        </button>
      </div>

      {erro && <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-600">{erro}</p>}
      {sucesso && (
        <p className="rounded-md bg-green-50 px-3 py-2 text-sm text-green-600">{sucesso}</p>
      )}

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[720px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="w-10 px-4 py-3" />
              <th className="px-4 py-3">Veículo</th>
              <th className="px-4 py-3">Óleo recomendado</th>
              <th className="px-4 py-3">Produto sugerido</th>
              <th className="px-4 py-3">Serviço sugerido</th>
            </tr>
          </thead>
          <tbody>
            {sugestoes.map((s) => {
              const completa = Boolean(s.produto_sugerido_id && s.servico_sugerido_id);
              return (
                <tr
                  key={s.veiculo_motor_id}
                  className="border-b border-slate-100 transition-colors hover:bg-slate-50"
                >
                  <td className="px-4 py-3">
                    <input
                      type="checkbox"
                      className="h-4 w-4 rounded border-slate-300 disabled:opacity-40"
                      checked={selecionados.has(s.veiculo_motor_id)}
                      onChange={() => alternar(s.veiculo_motor_id)}
                      disabled={!completa}
                    />
                  </td>
                  <td className="px-4 py-3 text-sm font-medium text-slate-900">
                    {s.marca} {s.modelo}
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-700">
                    {s.especificacao_oleo_recomendada}
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-700">
                    {s.produto_sugerido_label ?? (
                      <span className="text-slate-400">Nenhum produto compatível</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-700">
                    {s.servico_sugerido_label ?? (
                      <span className="text-slate-400">Nenhum serviço ativo compatível</span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
