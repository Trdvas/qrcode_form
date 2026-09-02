"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Mail, Lock } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

export default function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirectTo") || "/";

  const [email, setEmail] = useState("");
  const [senha, setSenha] = useState("");
  const [erro, setErro] = useState<string | null>(null);
  const [carregando, setCarregando] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErro(null);
    setCarregando(true);

    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password: senha });

    setCarregando(false);

    if (error) {
      setErro("E-mail ou senha inválidos.");
      return;
    }

    router.push(redirectTo);
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} className="card space-y-4 p-6">
      {erro && (
        <div className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-600">{erro}</div>
      )}
      <div>
        <label htmlFor="email" className="label">
          E-mail
        </label>
        <div className="relative">
          <Mail className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" strokeWidth={2} />
          <input
            id="email"
            type="email"
            required
            autoComplete="email"
            placeholder="voce@suaoficina.com.br"
            className="input pl-9"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
      </div>
      <div>
        <label htmlFor="senha" className="label">
          Senha
        </label>
        <div className="relative">
          <Lock className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" strokeWidth={2} />
          <input
            id="senha"
            type="password"
            required
            autoComplete="current-password"
            placeholder="••••••••"
            className="input pl-9"
            value={senha}
            onChange={(e) => setSenha(e.target.value)}
          />
        </div>
      </div>

      <div className="!mt-2 text-right">
        <a href="#" className="text-sm font-medium text-brand-600 hover:text-brand-700 hover:underline">
          Esqueci minha senha
        </a>
      </div>

      <button type="submit" disabled={carregando} className="btn-primary w-full">
        {carregando ? "Entrando..." : "Entrar"}
      </button>
    </form>
  );
}
