// Edge Function: welcome-email
//
// Disparada pelo trigger `trg_negocio_criado` (ver supabase/migrations/0001_init.sql)
// sempre que uma linha nova é inserida em `negocios`. Envia um e-mail de
// boas-vindas para o e-mail de contato do negócio via Resend.
//
// Deploy: supabase functions deploy welcome-email
// Secrets necessários: RESEND_API_KEY, EMAIL_REMETENTE

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore — módulo resolvido pelo runtime Deno das Edge Functions do Supabase.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

interface PayloadNegocioCriado {
  negocio_id: string;
  nome: string;
  email_contato: string;
}

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const EMAIL_REMETENTE = Deno.env.get("EMAIL_REMETENTE") ?? "Painel de Gestão <onboarding@resend.dev>";

function montarHtml(nomeNegocio: string) {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
      <h1 style="color:#2563eb;">Bem-vindo(a) ao Painel de Gestão!</h1>
      <p>Olá, equipe <strong>${nomeNegocio}</strong>,</p>
      <p>
        Seu negócio foi cadastrado com sucesso na plataforma. A partir de agora
        vocês podem acessar o painel para gerenciar produtos, serviços e
        acompanhar os agendamentos e orçamentos gerados pelo agente de IA no
        WhatsApp.
      </p>
      <p>Qualquer dúvida, é só responder este e-mail.</p>
      <p>Um abraço,<br/>Equipe Painel de Gestão</p>
    </div>
  `;
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const payload = (await req.json()) as PayloadNegocioCriado;

    if (!payload.email_contato) {
      return new Response(JSON.stringify({ error: "email_contato ausente" }), { status: 400 });
    }

    if (!RESEND_API_KEY) {
      console.error("RESEND_API_KEY não configurada; e-mail de boas-vindas não enviado.");
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: EMAIL_REMETENTE,
        to: payload.email_contato,
        subject: "Bem-vindo(a) ao Painel de Gestão",
        html: montarHtml(payload.nome),
      }),
    });

    if (!res.ok) {
      const detalhe = await res.text();
      console.error("Falha ao enviar e-mail de boas-vindas:", detalhe);
      return new Response(JSON.stringify({ error: detalhe }), { status: 502 });
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Erro inesperado na welcome-email:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
