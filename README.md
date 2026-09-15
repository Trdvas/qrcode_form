# Painel de Gestão

Plataforma web para o dono de um negócio (inicialmente oficinas mecânicas)
gerenciar produtos, serviços e agendamentos usados por um agente de IA no
WhatsApp. O banco de dados é a fonte de dados de um único negócio — não há
gestão de múltiplos negócios/tenants.

Stack: **Next.js 14 (App Router)** + **Tailwind CSS** + **Supabase**
(Auth + Postgres + RLS).

## Setup

### 1. Instalar dependências

```bash
npm install
```

### 2. Criar o projeto Supabase

1. Crie um projeto em https://supabase.com.
2. Rode a migration em `supabase/migrations/0001_init.sql` (via SQL Editor
   do Supabase Studio, ou `supabase db push` com a Supabase CLI). Ela cria:
   - a tabela singleton `negocio` (uma única linha, com nome e e-mail de
     contato do negócio);
   - `usuarios_perfil`, `produtos`, `servicos`, `agendamentos`, `orcamentos`;
   - RLS habilitado em todas as tabelas: qualquer usuário com perfil
     (`admin` ou `operador`) acessa livremente os dados operacionais
     (produtos, serviços, agendamentos, orçamentos); apenas `admin` edita os
     dados do negócio e gerencia perfis de usuário.
3. Em **Authentication → Providers**, garanta que o login por e-mail/senha
   está habilitado.

### 3. Criar o primeiro usuário administrador

Depois de criar um usuário via Supabase Auth (Studio → Authentication →
Add user), insira o perfil dele como admin:

```sql
insert into usuarios_perfil (id, role) values ('<uuid-do-usuario>', 'admin');
```

Demais integrantes da equipe recebem o perfil `operador`:

```sql
insert into usuarios_perfil (id, role) values ('<uuid-do-usuario>', 'operador');
```

### 4. Variáveis de ambiente

Copie `.env.local.example` para `.env.local` e preencha com as credenciais
do projeto Supabase (URL e anon key em Project Settings → API).

### 5. Rodar localmente

```bash
npm run dev
```

## Arquitetura

- **`middleware.ts`** — renova a sessão Supabase a cada requisição, resolve
  o `role` do usuário logado (via `usuarios_perfil`) e propaga isso como
  headers (`x-user-id`, `x-user-role`) para Server Components/Server
  Actions, além de proteger `/admin` para usuários com role `admin` e
  redirecionar `/` para `/dashboard`.
- **`lib/supabase/context.ts`** — lê esses headers e expõe helpers
  (`requireContext`, `requireAdmin`) usados em todas as páginas/actions
  autenticadas.
- **`app/(app)`** — área operacional (Dashboard, Produtos, Serviços,
  Agendamentos), acessível a qualquer usuário com perfil.
- **`app/admin`** — configurações do negócio único (nome, e-mail de
  contato), acessível apenas a usuários com role `admin`.
- **Segurança de dados**: toda leitura/escrita passa pelas policies de RLS
  do Postgres.

## Deploy

Projeto Next.js padrão — deploy direto na Vercel (ou similar). Configure
as mesmas variáveis de `.env.local` nas variáveis de ambiente do projeto
na plataforma de deploy.
