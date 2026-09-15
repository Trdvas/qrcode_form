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
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
