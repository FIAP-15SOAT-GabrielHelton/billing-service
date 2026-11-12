# frozen_string_literal: true

# Valida o JWT emitido pelo OS Service / auth-serverless (mesmo JWT_SECRET).
# Este serviço não tem a tabela de usuários: confia nas claims do token, então
# um usuário desativado segue válido até o access token expirar.
module JwtAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  private

  def authenticate!
    @token_payload = decode_bearer_token
    render_unauthorized unless staff? || customer?
  end

  def staff?
    @token_payload&.dig("type") == "access"
  end

  def customer?
    @token_payload&.dig("type") == "customer_access"
  end

  def require_staff!
    render_forbidden unless staff?
  end

  # Verdadeiro quando a requisição é de um customer tentando acessar um
  # recurso que não é seu (owner_id é o customer_id do recurso).
  def forbidden_for_customer?(owner_id)
    customer? && owner_id != @token_payload["sub"].to_i
  end

  def render_forbidden
    render json: { error: "Forbidden" }, status: :forbidden
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def decode_bearer_token
    header = request.headers["Authorization"].to_s
    return nil unless header.start_with?("Bearer ")

    ::Auth::JwtEncoder.new.decode(header.split(" ", 2).last)
  end
end
