"use client";

import { useTransition } from "react";
import { atualizarStatusAssinatura, atualizarPlano } from "@/app/admin/actions";

const STATUS_OPTIONS = ["trial", "ativo", "inadimplente", "cancelado"];
const PLANO_OPTIONS = ["trial", "basico", "pro"];

export default function StatusAssinaturaForm({
  negocioId,
  plano,
  statusAssinatura,
}: {
  negocioId: string;
  plano: string;
  statusAssinatura: string;
}) {
  const [pending, startTransition] = useTransition();

  return (
    <div className="flex flex-wrap gap-4">
      <div>
        <label className="label">Plano</label>
        <select
          className="input"
          defaultValue={plano}
          disabled={pending}
          onChange={(e) => startTransition(() => atualizarPlano(negocioId, e.target.value))}
        >
          {PLANO_OPTIONS.map((p) => (
            <option key={p} value={p}>
              {p}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label className="label">Status da assinatura</label>
        <select
          className="input"
          defaultValue={statusAssinatura}
          disabled={pending}
          onChange={(e) =>
            startTransition(() => atualizarStatusAssinatura(negocioId, e.target.value))
          }
        >
          {STATUS_OPTIONS.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}
