"use client";

import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import FiltroRow from "./filtro-row";

export interface FiltroComCarros {
  id: string;
  codigo: string;
  preco: number;
  motorizacoes: number;
  carros: string[];
}

function normalizar(s: string) {
  return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

export default function FiltrosLista({ filtros }: { filtros: FiltroComCarros[] }) {
  const [busca, setBusca] = useState("");

  const visiveis = useMemo(() => {
    const q = normalizar(busca.trim());
    if (!q) return filtros;
    return filtros.filter(
      (f) => normalizar(f.codigo).includes(q) || f.carros.some((c) => normalizar(c).includes(q)),
    );
  }, [busca, filtros]);

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="relative w-full max-w-sm">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <input
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Buscar por código ou carro (ex: WO130, Onix)"
            className="input w-full pl-9"
          />
        </div>
        <p className="text-sm text-slate-500">
          {visiveis.length} de {filtros.length} filtros
        </p>
      </div>

      <div className="card overflow-x-auto">
        <table className="w-full min-w-[640px]">
          <thead>
            <tr className="border-b border-slate-200 bg-slate-50 text-left text-xs font-semibold uppercase text-slate-500">
              <th className="px-4 py-3">Código</th>
              <th className="px-4 py-3">Carros que usam</th>
              <th className="px-4 py-3">Preço</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {visiveis.map((filtro) => (
              <FiltroRow key={filtro.id} filtro={filtro} />
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
