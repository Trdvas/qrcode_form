import Link from "next/link";

export default function SemAcessoPage() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 px-4 text-center">
      <h1 className="text-xl font-semibold text-gray-900">Conta sem acesso configurado</h1>
      <p className="max-w-md text-sm text-gray-500">
        Seu login foi criado, mas ainda não há um perfil vinculado a nenhum negócio. Entre em
        contato com o administrador da plataforma para liberar seu acesso.
      </p>
      <Link href="/login" className="btn-secondary">
        Voltar para o login
      </Link>
    </div>
  );
}
