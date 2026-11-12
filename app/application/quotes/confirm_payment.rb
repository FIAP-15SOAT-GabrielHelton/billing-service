# frozen_string_literal: true

require_relative "../shared/result"
require_relative "../shared/use_case"

module Quotes
  # Disparado pelo webhook do Mercado Pago. O corpo do webhook não é confiável: o pagamento
  # é sempre consultado na API do Mercado Pago, e só vale o que ela responder.
  class ConfirmPayment < Shared::UseCase
    EVENT = "payment.approved"

    def initialize(quote_repository:, payment_gateway:, publisher:)
      @repository = quote_repository
      @gateway = payment_gateway
      @publisher = publisher
    end

    private

    def perform(payment_id:)
      payment = @gateway.find_payment(payment_id)
      # Pagamento pendente ou recusado: nada a fazer, o cliente pode tentar de novo.
      return Shared::Result.success(nil) unless payment["status"] == "approved"

      quote = @repository.find_by_work_order_id(payment["external_reference"])
      return Shared::Result.failure("Quote not found") unless quote
      return Shared::Result.success(quote) if quote.paid?

      amount_cents = (payment["transaction_amount"].to_f * 100).round
      return Shared::Result.failure("Payment amount does not cover the quote") if amount_cents < quote.total.cents

      # Publica dentro da transação, como em ApproveQuote: sem evento, o pagamento não é gravado
      # e o Mercado Pago reenvia o webhook.
      ActiveRecord::Base.transaction do
        quote.pay(payment["id"])
        quote = @repository.save(quote)
        @publisher.publish(EVENT, { quote_id: quote.id, work_order_id: quote.work_order_id,
                                    payment_id: quote.payment_id, amount_cents: amount_cents })
      end

      Shared::Result.success(quote)
    end
  end
end
