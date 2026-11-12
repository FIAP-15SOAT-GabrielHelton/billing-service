# frozen_string_literal: true

module Messaging
  # Eventos da Saga (RFC-005) que este serviço consome.
  module EventHandlers
    QUEUE = "billing-service"

    def self.build(quote_repository: Persistence::Quotes::ActiveRecordQuoteRepository.new)
      {
        "work_order.diagnosed" => lambda do |data|
          result = Quotes::CreateQuote.new(quote_repository: quote_repository).call(
            work_order_id: data.fetch("work_order_id"),
            customer_id: data.fetch("customer_id"),
            line_items: data.fetch("line_items")
          )
          raise result.error if result.failure?
        end
      }
    end
  end
end
