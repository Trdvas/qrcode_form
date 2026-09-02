"use client";

import { useRef, useState } from "react";
import { criarServico } from "./actions";

export default function NovoServicoForm() {
  const formRef = useRef<HTMLFormElement>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [aberto, setAberto] = useState(false);

  async function handleSubmit(formData: FormData) {
    setErro(null);
    try {
      await criarServico(formData);
      formRef.current?.reset();
      setAberto(false);
    } catch (e) {
      setErro(e instanceof Error ? e.message : "Erro ao salvar.");
    }
  }

  if (!aberto) {
    return (
      <button className="btn-primary" onClick={() => setAberto(true)}>
        + Novo serviço
      </button>
    );
  }

  return (
    <form ref={formRef} action={handleSubmit} className="card flex flex-wrap items-end gap-3 p-4">
      <div>
        <label className="label">Nome</label>
        <input name="nome" required className="input" placeholder="Ex: Troca de óleo" />
      </div>
      <div>
        <label className="label">Mão de obra (R$)</label>
        <input
          name="preco_mao_obra"
          type="number"
          step="0.01"
          min="0"
          required
          className="input w-32"
        />
      </div>
      <div className="flex gap-2">
        <button type="submit" className="btn-primary">
          Salvar
        </button>
        <button type="button" className="btn-secondary" onClick={() => setAberto(false)}>
          Cancelar
        </button>
      </div>
      {erro && <p className="w-full text-sm text-red-600">{erro}</p>}
    </form>
  );
}
