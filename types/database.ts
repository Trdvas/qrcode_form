// Tipos manuais espelhando o schema Supabase definido em supabase/migrations/0001_init.sql.
// Se preferir, substitua por tipos gerados via `supabase gen types typescript`.

export type Role = "dono_negocio" | "admin_plataforma";

export type StatusAssinatura = "ativo" | "inadimplente" | "cancelado" | "trial";

export type StatusAgendamento = "confirmado" | "concluido" | "cancelado";

export type StatusOrcamento = "enviado" | "em_negociacao" | "aprovado" | "recusado" | "expirado";

export interface Negocio {
  id: string;
  nome: string;
  email_contato: string;
  plano: string;
  status_assinatura: StatusAssinatura | string;
  criado_em: string;
}

export interface UsuarioPerfil {
  id: string;
  negocio_id: string | null;
  role: Role;
  criado_em: string;
}

export interface Produto {
  id: string;
  negocio_id: string;
  marca: string;
  especificacao: string;
  preco_litro: number;
  criado_em: string;
}

export interface Servico {
  id: string;
  negocio_id: string;
  nome: string;
  preco_mao_obra: number;
  ativo: boolean;
  criado_em: string;
}

export interface Agendamento {
  id: string;
  negocio_id: string;
  session_id: string;
  veiculo: string | null;
  data_hora_inicio: string;
  data_hora_fim: string;
  status: StatusAgendamento | string;
  criado_em: string;
}

export interface Orcamento {
  id: string;
  negocio_id: string;
  session_id: string;
  veiculo: string | null;
  valor_total: number | null;
  status: StatusOrcamento | string;
  data_criacao: string;
  data_ultimo_contato: string | null;
}

export interface VeiculoMotor {
  id: string;
  negocio_id: string;
  marca: string;
  modelo: string;
  especificacao_oleo_recomendada: string;
  produto_oleo_motor_id: string | null;
  servico_motor_id: string | null;
  criado_em: string;
}

/** Linha retornada pela function `sugerir_produtos_motor(p_negocio_id)`. */
export interface SugestaoProdutoMotor {
  veiculo_motor_id: string;
  marca: string;
  modelo: string;
  especificacao_oleo_recomendada: string;
  produto_atual_id: string | null;
  servico_atual_id: string | null;
  produto_sugerido_id: string | null;
  produto_sugerido_label: string | null;
  servico_sugerido_id: string | null;
  servico_sugerido_label: string | null;
}

export interface Database {
  public: {
    Tables: {
      negocios: {
        Row: Negocio;
        Insert: Partial<Negocio> & { nome: string; email_contato: string };
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
          negocio_id: string;
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
          negocio_id: string;
          nome: string;
          preco_mao_obra: number;
        };
        Update: Partial<Servico>;
        Relationships: [];
      };
      agendamentos: {
        Row: Agendamento;
        Insert: Partial<Agendamento> & {
          negocio_id: string;
          session_id: string;
          data_hora_inicio: string;
          data_hora_fim: string;
        };
        Update: Partial<Agendamento>;
        Relationships: [];
      };
      orcamentos: {
        Row: Orcamento;
        Insert: Partial<Orcamento> & { negocio_id: string; session_id: string };
        Update: Partial<Orcamento>;
        Relationships: [];
      };
      veiculos_motor: {
        Row: VeiculoMotor;
        Insert: Partial<VeiculoMotor> & {
          negocio_id: string;
          marca: string;
          modelo: string;
          especificacao_oleo_recomendada: string;
        };
        Update: Partial<VeiculoMotor>;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      sugerir_produtos_motor: {
        Args: { p_negocio_id: string };
        Returns: SugestaoProdutoMotor[];
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
