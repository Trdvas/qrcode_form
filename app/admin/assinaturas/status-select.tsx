"use client";

import { useTransition } from "react";
import { atualizarStatusAssinatura } from "@/app/admin/actions";

const STATUS_OPTIONS = [
  { value: "trial", label: "Trial" },
  { value: "ativo", label: "Ativo" },
  { value: "inadimplente", label: "Inadimplente" },
  { value: "cancelado", label: "Cancelado" },
];

export default function StatusSelect({
  negocioId,
  statusAtual,
}: {
  negocioId: string;
  statusAtual: string;
}) {
  const [pending, startTransition] = useTransition();

  return (
    <select
      className="input h-9 w-full max-w-[180px] py-0 text-sm"
      defaultValue={statusAtual}
      disabled={pending}
      onChange={(e) => startTransition(() => atualizarStatusAssinatura(negocioId, e.target.value))}
    >
      {STATUS_OPTIONS.map((opt) => (
        <option key={opt.value} value={opt.value}>
          {opt.label}
        </option>
      ))}
    </select>
  );
}
