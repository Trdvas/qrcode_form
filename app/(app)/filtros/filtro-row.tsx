"use client";

import { useState } from "react";
import { ChevronDown, ChevronRight, Pencil } from "lucide-react";
import { atualizarPrecoFiltro } from "./actions";
import { aplicacaoBate, type Aplicacao, type FiltroComCarros } from "./filtros-lista";

function formatBRL(v: number) {
  return v.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

function anos(a: Aplicacao) {
  if (a.anoInicio == null && a.anoFim == null) return "—";
  if (a.anoInicio === a.anoFim || a.anoFim == null) return String(a.anoInicio ?? a.anoFim);
  if (a.anoInicio == null) return `até ${a.anoFim}`;
  return `${a.anoInicio} a ${a.anoFim}`;
}

export default function FiltroRow({
  filtro,
  busca,
  abertoInicial,
}: {
  filtro: FiltroComCarros;
  busca: string;
  abertoInicial: boolean;
}) {
  const [editando, setEditando] = useState(false);
  const [aberto, setAberto] = useState(abertoInicial);
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

  const modelos = Array.from(new Set(filtro.aplicacao.map((a) => `${a.modelo}`)));
  const resumo = modelos.slice(0, 4).join(", ") + (modelos.length > 4 ? ` e mais ${modelos.length - 4}` : "");
  const termos = busca ? busca.split(/\s+/) : [];
  const destaca = (a: Aplicacao) => termos.length > 0 && aplicacaoBate(a, termos);

  return (
    <>
      <tr className="border-b border-slate-100 align-top transition-colors hover:bg-slate-50">
        <td className="px-4 py-3 text-sm font-medium text-slate-900">{filtro.codigo}</td>
        <td className="px-4 py-3 text-sm text-slate-700">
          {filtro.aplicacao.length === 0 ? (
            <span className="text-slate-400">Nenhum carro ligado</span>
          ) : (
            <button
              type="button"
              onClick={() => setAberto((a) => !a)}
              className="flex items-start gap-1 text-left hover:text-brand-600"
            >
              {aberto ? (
                <ChevronDown className="mt-0.5 h-4 w-4 shrink-0" />
              ) : (
                <ChevronRight className="mt-0.5 h-4 w-4 shrink-0" />
              )}
              <span>
                {resumo}
                <span className="block text-xs text-slate-400">
                  {filtro.aplicacao.length} aplicações — clique para {aberto ? "recolher" : "ver modelo, motor e ano"}
                </span>
              </span>
            </button>
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
      {aberto && filtro.aplicacao.length > 0 && (
        <tr className="border-b border-slate-200 bg-slate-50/60">
          <td />
          <td colSpan={3} className="px-4 pb-4 pt-1">
            <table className="w-full max-w-2xl text-sm">
              <thead>
                <tr className="text-left text-xs uppercase text-slate-400">
                  <th className="py-1 pr-4 font-medium">Montadora</th>
                  <th className="py-1 pr-4 font-medium">Modelo</th>
                  <th className="py-1 pr-4 font-medium">Motor</th>
                  <th className="py-1 font-medium">Ano</th>
                </tr>
              </thead>
              <tbody>
                {filtro.aplicacao.map((a, i) => (
                  <tr
                    key={i}
                    className={`border-t border-slate-100 ${destaca(a) ? "bg-amber-50 font-medium text-slate-900" : "text-slate-700"}`}
                  >
                    <td className="py-1 pr-4">{a.montadora}</td>
                    <td className="py-1 pr-4">{a.modelo}</td>
                    <td className="py-1 pr-4">{a.motor}</td>
                    <td className="py-1 whitespace-nowrap">{anos(a)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </td>
        </tr>
      )}
    </>
  );
}
