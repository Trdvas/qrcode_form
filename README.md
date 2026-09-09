# Painel de Gestão (Multi-Negócios)

Plataforma web multi-tenant para donos de negócios (inicialmente oficinas
mecânicas) gerenciarem produtos, serviços e agendamentos usados por um
agente de IA no WhatsApp. Cada negócio só acessa seus próprios dados; um
admin da plataforma gerencia todos os negócios e assinaturas.

Stack: **Next.js 14 (App Router)** + **Tailwind CSS** + **Supabase**
(Auth + Postgres + RLS + Edge Functions).

## Setup

### 1. Instalar dependências

```bash
npm install
```

### 2. Criar o projeto Supabase

1. Crie um projeto em https://supabase.com.
2. Rode as migrations em `supabase/migrations/` (em ordem, via SQL Editor
   do Supabase Studio, ou `supabase db push` com a Supabase CLI).
   `0001_init.sql` cria:
   - as tabelas `negocios`, `usuarios_perfil`, `produtos`, `servicos`,
     `agendamentos`, `orcamentos`;
   - RLS habilitado em todas as tabelas de dados de negócio, com a policy
     padrão (`dono_negocio` só acessa `negocio_id = auth_negocio_id()`) e a
     policy de admin (`admin_plataforma` acessa tudo);
   - o trigger `trg_negocio_criado`, que dispara a Edge Function
     `welcome-email` a cada `insert` em `negocios`.

   `0002_veiculos_motor.sql` só cria a function `sugerir_produtos_motor
   (p_negocio_id)` — a tabela `veiculos_motor` já existe em produção e não é
   criada/alterada por esta migration. A function é usada pela tela
   **Produtos e Serviços → Vincular veículos** (`/produtos/vincular`) para
   sugerir automaticamente, a partir da `viscosidade_recomendada` de cada
   veículo ainda sem `produto_oleo_motor_id`, o produto (óleo) compatível
   cadastrado. O serviço (`servico_motor_id`) não é sugerido — o usuário
   escolhe manualmente, em um dropdown com os serviços ativos do negócio,
   qual serviço vincular; produto e serviço são obrigatórios, e nada é
   gravado se algum par selecionado estiver incompleto.
3. Deploy da Edge Function de e-mail de boas-vindas:
   ```bash
   supabase functions deploy welcome-email
   supabase secrets set RESEND_API_KEY=... EMAIL_REMETENTE="Painel de Gestão <contato@seudominio.com>"
   ```
4. Configure as settings usadas pelo trigger (uma vez por projeto):
   ```sql
   alter database postgres set app.settings.supabase_url = 'https://SEU-PROJETO.supabase.co';
   alter database postgres set app.settings.service_role_key = 'SUA_SERVICE_ROLE_KEY';
   ```
5. Em **Authentication → Providers**, garanta que o login por e-mail/senha
   está habilitado.

### 3. Criar o primeiro admin da plataforma

Depois de criar um usuário via Supabase Auth (Studio → Authentication →
Add user), insira o perfil dele como admin:

```sql
insert into usuarios_perfil (id, role) values ('<uuid-do-usuario>', 'admin_plataforma');
```

Donos de negócio recebem o perfil correspondente ao serem vinculados a um
negócio (feito pelo admin, ou manualmente):

```sql
insert into usuarios_perfil (id, negocio_id, role)
values ('<uuid-do-usuario>', '<uuid-do-negocio>', 'dono_negocio');
```

### 4. Variáveis de ambiente

Copie `.env.local.example` para `.env.local` e preencha com as credenciais
do projeto Supabase (URL e anon key em Project Settings → API).

### 5. Rodar localmente

```bash
npm run dev
```

## Arquitetura

- **`middleware.ts`** — renova a sessão Supabase a cada requisição,
  resolve `role` + `negocio_id` do usuário logado (via `usuarios_perfil`) e
  propaga isso como headers (`x-user-id`, `x-user-role`, `x-negocio-id`)
  para Server Components/Server Actions, além de proteger rotas por papel
  e redirecionar `/` para `/dashboard` (dono) ou `/admin/negocios` (admin).
- **`lib/supabase/context.ts`** — lê esses headers e expõe helpers
  (`requireContext`, `requireNegocioContext`, `requireAdmin`) usados em
  todas as páginas/actions autenticadas.
- **`app/(app)`** — área operacional do dono de negócio: Dashboard,
  Produtos, Serviços, Agendamentos.
- **`app/admin`** — área do admin da plataforma: lista de negócios,
  cadastro de negócio novo, detalhe com status de assinatura e acesso em
  "modo suporte" (o admin passa a operar temporariamente como se fosse o
  negócio selecionado, via cookie `admin_view_negocio_id`).
- **Segurança de dados**: toda leitura/escrita passa pelas policies de RLS
  do Postgres — o isolamento por `negocio_id` não depende só do filtro
  feito no código, ele é garantido no banco.

## Deploy

Projeto Next.js padrão — deploy direto na Vercel (ou similar). Configure
as mesmas variáveis de `.env.local` nas variáveis de ambiente do projeto
na plataforma de deploy.
