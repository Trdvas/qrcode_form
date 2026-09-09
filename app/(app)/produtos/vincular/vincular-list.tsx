"use client";

import { useMemo, useState, useTransition } from "react";
import { CheckCircle2 } from "lucide-react";
import type { Servico, SugestaoProdutoMotor } from "@/types/database";
import { confirmarVinculos, type ParVinculo } from "./actions";

function chave(s: SugestaoProdutoMotor) {
  return `${s.veiculo_id}:${s.produto_id}`;
}

export default function VincularList({
  sugestoes,
  servicosAtivos,
}: {
  sugestoes: SugestaoProdutoMotor[];
  servicosAtivos: Servico[];
}) {
  const [selecionados, setSelecionados] = useState<Set<string>>(new Set());
  const [servicoPorVeiculo, setServicoPorVeiculo] = useState<Record<string, string>>({});
  const [pending, startTransition] = useTransition();
  const [erro, setErro] = useState<string | null>(null);
  const [sucesso, setSucesso] = useState<string | null>(null);

  const todasChaves = useMemo(() => sugestoes.map(chave), [sugestoes]);
  const todosSelecionados = todasChaves.length > 0 && todasChaves.every((k) => selecionados.has(k));

  // Um veículo pode ter mais de uma opção de produto compatível — mas só um
  // produto pode ficar vinculado. Selecionar uma linha desmarca as outras
  // linhas do mesmo veículo, para nunca mandar dois pares conflitantes.
  function alternar(s: SugestaoProdutoMotor) {
    const k = chave(s);
    setSelecionados((atual) => {
      const novo = new Set(atual);
      if (novo.has(k)) {
        novo.delete(k);
        return novo;
      }
      for (const outra of sugestoes) {
        if (outra.veiculo_id === s.veiculo_id) novo.delete(chave(outra));
      }
      novo.add(k);
      return novo;
    });
  }

  function alternarTodos() {
    if (todosSelecionados) {
      setSelecionados(new Set());
      return;
    }
    // Ao marcar tudo, fica só a primeira opção de cada veículo.
    const vistos = new Set<string>();
    const novo = new Set<string>();
    for (const s of sugestoes) {
      if (vistos.has(s.veiculo_id)) continue;
      vistos.add(s.veiculo_id);
      novo.add(chave(s));
    }
    setSelecionados(novo);
  }

  function selecionarServico(veiculoId: string, servicoId: string) {
    setServicoPorVeiculo((atual) => ({ ...atual, [veiculoId]: servicoId }));
  }

  function handleConfirmar() {
    setErro(null);
    setSucesso(null);

    const linhasSelecionadas = sugestoes.filter((s) => selecionados.has(chave(s)));
    const semServico = linhasSelecionadas.find((s) => !servicoPorVeiculo[s.veiculo_id]);
    if (semServico) {
      setErro(
        `Escolha um serviço para "${semServico.montadora} ${semServico.modelo}" antes de confirmar.`
      );
      return;
    }

    const pares: ParVinculo[] = linhasSelecionadas.map((s) => ({
      veiculoId: s.veiculo_id,
      produtoId: s.produto_id,
      servicoId: servicoPorVeiculo[s.veiculo_id],
    }));

    startTransition(async () => {
      try {
        await confirmarVinculos(pares);
        setSucesso(`${pares.length} veículo(s) vinculado(s) com sucesso.`);
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
          />
          Selecionar todos
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
        <table className="w-full min-w-[860px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="w-10 px-4 py-3" />
              <th className="px-4 py-3">Veículo</th>
              <th className="px-4 py-3">Motor</th>
              <th className="px-4 py-3">Viscosidade</th>
              <th className="px-4 py-3">Produto sugerido</th>
              <th className="px-4 py-3">Serviço *</th>
            </tr>
          </thead>
          <tbody>
            {sugestoes.map((s) => {
              const k = chave(s);
              const anos =
                s.ano_inicio || s.ano_fim
                  ? `${s.ano_inicio ?? "?"}–${s.ano_fim ?? "atual"}`
                  : null;
              return (
                <tr key={k} className="border-b border-slate-100 transition-colors hover:bg-slate-50">
                  <td className="px-4 py-3">
                    <input
                      type="checkbox"
                      className="h-4 w-4 rounded border-slate-300"
                      checked={selecionados.has(k)}
                      onChange={() => alternar(s)}
                    />
                  </td>
                  <td className="px-4 py-3 text-sm font-medium text-slate-900">
                    {s.montadora} {s.modelo}
                    {anos && <span className="ml-1.5 font-normal text-slate-500">{anos}</span>}
                  </td>
                  <td className="px-4 py-3 text-sm text-slate-700">{s.motor_descricao ?? "—"}</td>
                  <td className="px-4 py-3 text-sm text-slate-700">{s.opcao_viscosidade}</td>
                  <td className="px-4 py-3 text-sm text-slate-700">
                    {s.produto_marca} — {s.produto_especificacao}
                  </td>
                  <td className="px-4 py-3">
                    <select
                      className="input h-9 min-w-[180px] py-0 text-sm"
                      value={servicoPorVeiculo[s.veiculo_id] ?? ""}
                      onChange={(e) => selecionarServico(s.veiculo_id, e.target.value)}
                      disabled={servicosAtivos.length === 0}
                    >
                      <option value="">Selecione um serviço</option>
                      {servicosAtivos.map((servico) => (
                        <option key={servico.id} value={servico.id}>
                          {servico.nome}
                        </option>
                      ))}
                    </select>
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
