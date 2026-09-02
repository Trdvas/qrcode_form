// O middleware sempre redireciona "/" para /dashboard ou /admin/negocios
// conforme o papel do usuário logado (ou para /login se não autenticado).
export default function RootPage() {
  return null;
}
