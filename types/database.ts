// Tipos manuais espelhando o schema Supabase definido em supabase/migrations/0001_init.sql.
// Se preferir, substitua por tipos gerados via `supabase gen types typescript`.

export type Role = "admin" | "operador";

export type StatusAgendamento = "confirmado" | "concluido" | "cancelado";

export type StatusOrcamento = "enviado" | "em_negociacao" | "aprovado" | "recusado" | "expirado";

/** Dados do único negócio administrado por este painel (tabela singleton). */
export interface Negocio {
  id: true;
  nome: string;
  email_contato: string;
  criado_em: string;
}

export interface UsuarioPerfil {
  id: string;
  role: Role;
  criado_em: string;
}

export interface Produto {
  id: string;
  marca: string;
  especificacao: string;
  preco_litro: number;
  criado_em: string;
}

/** Filtro (tabela `filtros`). O preço é lido pelo bot na hora de orçar a troca de óleo. */
export interface Filtro {
  id: string;
  codigo: string;
  descricao: string | null;
  preco: number;
  criado_em: string;
}

export interface Servico {
  id: string;
  nome: string;
  preco_mao_obra: number;
  ativo: boolean;
  criado_em: string;
}

export interface Agendamento {
  id: string;
  session_id: string;
  veiculo: string | null;
  data_hora_inicio: string;
  data_hora_fim: string;
  status: StatusAgendamento | string;
  criado_em: string;
}

export interface Orcamento {
  id: string;
  session_id: string;
  veiculo: string | null;
  valor_total: number | null;
  status: StatusOrcamento | string;
  data_criacao: string;
  data_ultimo_contato: string | null;
}

/**
 * Oferta de retorno enviada pelo bot no follow-up de orçamento (view `ofertas_retorno_painel`).
 * 20% de desconto no óleo à vista ou 10% no óleo no cartão, válida ~48h.
 * "base_*" = opção citada na mensagem; "fechou_*" = opção que o cliente fechou durante a oferta (preço já com a oferta).
 */
export interface OfertaRetornoPainel {
  id: string;
  session_id: string;
  origem: "orcamento" | "cotacao";
  enviado_em: string;
  valido_ate: string;
  ativa: boolean;
  pct_avista: number;
  pct_cartao: number;
  tipo: "motor" | "cambio";
  carro: string;
  base_marca: string | null;
  base_avista: number | null;
  base_cartao: number | null;
  base_parcelas: number | null;
  base_parcela: number | null;
  orcamento_id: string | null;
  fechou_marca: string | null;
  fechou_avista: number | null;
  fechou_cartao: number | null;
  fechou_parcelas: number | null;
  fechou_parcela: number | null;
  agendamento_id: string | null;
  agendamento_inicio: string | null;
  agendamento_status: string | null;
}

export interface Database {
  public: {
    Tables: {
      negocio: {
        Row: Negocio;
        Insert: Partial<Negocio>;
        Update: Partial<Negocio>;
        Relationships: [];
      };
      usuarios_perfil: {
        Row: UsuarioPerfil;
        Insert: Partial<UsuarioPerfil> & { id: string; role: Role };
        Update: Partial<UsuarioPerfil>;
        Relationships: [];
      };
      produtos: {
        Row: Produto;
        Insert: Partial<Produto> & {
          marca: string;
          especificacao: string;
          preco_litro: number;
        };
        Update: Partial<Produto>;
        Relationships: [];
      };
      servicos: {
        Row: Servico;
        Insert: Partial<Servico> & {
          nome: string;
          preco_mao_obra: number;
        };
        Update: Partial<Servico>;
        Relationships: [];
      };
      agendamentos: {
        Row: Agendamento;
        Insert: Partial<Agendamento> & {
          session_id: string;
          data_hora_inicio: string;
          data_hora_fim: string;
        };
        Update: Partial<Agendamento>;
        Relationships: [];
      };
      orcamentos: {
        Row: Orcamento;
        Insert: Partial<Orcamento> & { session_id: string };
        Update: Partial<Orcamento>;
        Relationships: [];
      };
    };
    Views: {
      ofertas_retorno_painel: {
        Row: OfertaRetornoPainel;
        Relationships: [];
      };
    };
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
