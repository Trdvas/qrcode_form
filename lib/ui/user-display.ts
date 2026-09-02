/**
 * O schema não guarda um campo "nome" para o usuário — apenas o e-mail do
 * Supabase Auth. Estas funções derivam um nome de exibição e iniciais a
 * partir do e-mail, só para o avatar/cabeçalho (não alteram dados).
 */
export function nomeFromEmail(email: string | null | undefined): string {
  if (!email) return "Usuário";
  const local = email.split("@")[0] || "";
  const nome = local
    .split(/[._-]+/)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
  return nome || "Usuário";
}

export function iniciaisFromEmail(email: string | null | undefined): string {
  const nome = nomeFromEmail(email);
  const partes = nome.split(" ").filter(Boolean);
  if (partes.length === 0) return "U";
  if (partes.length === 1) return partes[0].slice(0, 2).toUpperCase();
  return (partes[0][0] + partes[1][0]).toUpperCase();
}
