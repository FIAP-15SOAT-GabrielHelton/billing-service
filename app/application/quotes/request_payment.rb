# frozen_string_literal: true

require_relative "../shared/result"
require_relative "../shared/use_case"

module Quotes
  # Disparado por execution.completed: o serviço terminou, então cria a cobrança no Mercado Pago.
  class RequestPayment < Shared::UseCase
    def initialize(quote_repository:, payment_gateway:)
      @repository = quote_repository
      @gateway = payment_gateway
    end

    private

    def perform(work_order_id:)
      quote = @repository.find_by_work_order_id(work_order_id)
      # Idempotência: só cobra orçamento aprovado e ainda sem cobrança criada.
      return Shared::Result.success(quote) if quote.nil? || !quote.approved? || quote.payment_url

      quote.request_payment(@gateway.create_preference(quote))
      Shared::Result.success(@repository.save(quote))
    end
  end
end
