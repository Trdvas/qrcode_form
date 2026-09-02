import { Suspense } from "react";
import { Wrench } from "lucide-react";
import LoginForm from "./login-form";

export default function LoginPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-slate-50 px-4">
      <div className="w-full max-w-[360px]">
        <div className="mb-8 flex flex-col items-center text-center">
          <span className="mb-4 flex h-12 w-12 items-center justify-center rounded-xl bg-brand-600 text-white">
            <Wrench className="h-6 w-6" strokeWidth={2} />
          </span>
          <h1 className="text-2xl font-bold text-slate-900">Painel de Gestão</h1>
          <p className="mt-1 text-sm text-slate-500">Entre com sua conta para continuar</p>
        </div>
        <Suspense fallback={null}>
          <LoginForm />
        </Suspense>
        <p className="mt-6 text-center text-xs text-slate-500">
          Problemas para acessar? Fale com o suporte da plataforma.
        </p>
      </div>
    </div>
  );
}
