# frozen_string_literal: true

require_relative "../shared/result"
require_relative "../shared/use_case"

module Quotes
  # Cria o orçamento a partir do evento work_order.diagnosed (RFC-005).
  class CreateQuote < Shared::UseCase
    def initialize(quote_repository:)
      @repository = quote_repository
    end

    private

    def perform(work_order_id:, customer_id:, line_items:)
      # Idempotência: o broker pode reentregar o mesmo evento.
      existing = @repository.find_by_work_order_id(work_order_id)
      return Shared::Result.success(existing) if existing

      quote = Quote.new(
        id: nil,
        work_order_id: work_order_id,
        customer_id: customer_id,
        line_items: line_items.map { |item| build_line_item(item) }
      )

      Shared::Result.success(@repository.save(quote))
    end

    def build_line_item(item)
      QuoteLineItem.new(
        id: nil,
        description: item.fetch("name"),
        quantity: item.fetch("quantity"),
        unit_price: item.fetch("unit_price_cents")
      )
    end
  end
end
