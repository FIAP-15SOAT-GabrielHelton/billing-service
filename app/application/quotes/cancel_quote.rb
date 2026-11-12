# frozen_string_literal: true

require_relative "../shared/result"
require_relative "../shared/use_case"

module Quotes
  # Compensação da Saga (RFC-005): a OS foi cancelada, então o orçamento deixa de valer.
  class CancelQuote < Shared::UseCase
    def initialize(quote_repository:)
      @repository = quote_repository
    end

    private

    def perform(work_order_id:)
      quote = @repository.find_by_work_order_id(work_order_id)
      # Idempotência: nada a desfazer se não há orçamento ou se já foi encerrado.
      return Shared::Result.success(quote) if quote.nil? || quote.status.terminal?

      quote.cancel
      Shared::Result.success(@repository.save(quote))
    end
  end
end
