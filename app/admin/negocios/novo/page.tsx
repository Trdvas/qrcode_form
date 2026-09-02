import { requireAdmin } from "@/lib/supabase/context";
import { criarNegocio } from "@/app/admin/actions";

export default async function NovoNegocioPage() {
  await requireAdmin();

  return (
    <div className="max-w-lg space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Novo negócio</h1>
        <p className="text-sm text-slate-500">
          Ao salvar, um e-mail de boas-vindas é enviado automaticamente para o e-mail de contato.
        </p>
      </div>

      <form action={criarNegocio} className="card space-y-4 p-6">
        <div>
          <label htmlFor="nome" className="label">
            Nome do negócio
          </label>
          <input id="nome" name="nome" required className="input" placeholder="Oficina do João" />
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
            placeholder="contato@oficinadojoao.com.br"
          />
        </div>
        <div>
          <label htmlFor="plano" className="label">
            Plano
          </label>
          <select id="plano" name="plano" defaultValue="trial" className="input">
            <option value="trial">Trial</option>
            <option value="basico">Básico</option>
            <option value="pro">Pro</option>
          </select>
        </div>
        <button type="submit" className="btn-primary w-full">
          Cadastrar negócio
        </button>
      </form>
    </div>
  );
}
