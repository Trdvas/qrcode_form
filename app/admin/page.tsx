import { requireAdmin } from "@/lib/supabase/context";
import { createClient } from "@/lib/supabase/server";
import type { Negocio } from "@/types/database";
import { atualizarNegocio } from "./actions";

export default async function ConfiguracoesPage() {
  await requireAdmin();
  const supabase = createClient();

  const { data: negocio } = await supabase
    .from("negocio")
    .select("*")
    .eq("id", true)
    .maybeSingle<Negocio>();

  return (
    <div className="max-w-lg space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Configurações do negócio</h1>
        <p className="text-sm text-slate-500">Dados usados no painel e nos contatos do negócio</p>
      </div>

      <form action={atualizarNegocio} className="card space-y-4 p-6">
        <div>
          <label htmlFor="nome" className="label">
            Nome do negócio
          </label>
          <input
            id="nome"
            name="nome"
            required
            className="input"
            defaultValue={negocio?.nome ?? ""}
            placeholder="Oficina do João"
          />
        </div>
        <div>
          <label htmlFor="email_contato" className="label">
            E-mail de contato
          </label>
          <input
            id="email_contato"
            name="email_contato"
            type="email"
            required
            className="input"
            defaultValue={negocio?.email_contato ?? ""}
            placeholder="contato@oficinadojoao.com.br"
          />
        </div>
        <button type="submit" className="btn-primary w-full">
          Salvar alterações
        </button>
      </form>
    </div>
  );
}
