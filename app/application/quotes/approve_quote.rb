# frozen_string_literal: true

require_relative "../shared/result"
require_relative "../shared/use_case"

module Quotes
  class ApproveQuote < Shared::UseCase
    EVENT = "quote.approved"

    def initialize(quote_repository:, publisher:)
      @repository = quote_repository
      @publisher = publisher
    end

    private

    def perform(id:, quote: nil)
      quote ||= @repository.find(id)
      return Shared::Result.failure("Quote not found") unless quote

      # Publica dentro da transação: se o broker falhar, a decisão não é gravada
      # e o cliente pode tentar de novo, em vez de a Saga travar sem o evento.
      ActiveRecord::Base.transaction do
        quote.approve
        quote = @repository.save(quote)
        @publisher.publish(EVENT, { quote_id: quote.id, work_order_id: quote.work_order_id,
                                    total_cents: quote.total.cents })
      end

      Shared::Result.success(quote)
    end
  end
end
