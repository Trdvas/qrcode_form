"use client";

import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import FiltroRow from "./filtro-row";

export interface Aplicacao {
  montadora: string;
  modelo: string;
  motor: string;
  anoInicio: number | null;
  anoFim: number | null;
}

export interface FiltroComCarros {
  id: string;
  codigo: string;
  preco: number;
  aplicacao: Aplicacao[];
}

export function normalizar(s: string) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

/**
 * A aplicação bate com todos os termos da busca? Ano de 4 dígitos vale se estiver dentro da faixa
 * (ex.: "onix 2018" acha Onix 2017 a 2021); os demais termos procuram em montadora/modelo/motor.
 */
export function aplicacaoBate(a: Aplicacao, termos: string[]) {
  const texto = normalizar(`${a.montadora} ${a.modelo} ${a.motor}`);
  return termos.every((t) => {
    if (/^(19|20)\d\d$/.test(t)) {
      const ano = Number(t);
      return (a.anoInicio ?? 0) <= ano && ano <= (a.anoFim ?? 9999);
    }
    return texto.includes(t);
  });
}

export default function FiltrosLista({ filtros }: { filtros: FiltroComCarros[] }) {
  const [busca, setBusca] = useState("");
  const [todosAbertos, setTodosAbertos] = useState(false);
  const q = normalizar(busca.trim());

  const visiveis = useMemo(() => {
    if (!q) return filtros;
    const termos = q.split(/\s+/);
    return filtros.filter(
      (f) =>
        normalizar(f.codigo).includes(q) ||
        f.aplicacao.some((a) => aplicacaoBate(a, termos)),
    );
  }, [q, filtros]);

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="relative w-full max-w-sm">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <input
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Buscar código ou carro (ex: WO130, Onix 2018)"
            className="input w-full pl-9"
          />
        </div>
        <div className="flex items-center gap-3">
          <button type="button" className="btn-secondary" onClick={() => setTodosAbertos((a) => !a)}>
            {todosAbertos ? "Recolher aplicações" : "Ver todas as aplicações"}
          </button>
          <p className="text-sm text-slate-500">
            {visiveis.length} de {filtros.length} filtros
          </p>
        </div>
      </div>

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[720px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="px-4 py-3">Código</th>
              <th className="px-4 py-3">Aplicação</th>
              <th className="px-4 py-3">Preço</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {visiveis.map((filtro) => (
              <FiltroRow
                key={`${filtro.id}-${todosAbertos}`}
                filtro={filtro}
                busca={q}
                abertoInicial={todosAbertos || q.length > 0}
              />
            ))}
          </tbody>
        </table>
        {visiveis.length === 0 && (
          <p className="px-4 py-8 text-center text-sm text-slate-500">Nenhum filtro encontrado.</p>
        )}
      </div>
    </div>
  );
}
