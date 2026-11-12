# frozen_string_literal: true

module Api
  module V1
    class QuotesController < Api::V1::ApplicationController
      before_action :require_staff!, only: %i[send_to_customer]

      def show
        quote_res = find_quote.call(id: params[:id])
        return render(json: { error: quote_res.error }, status: :not_found) if quote_res.failure?

        quote = quote_res.value
        return render_forbidden if forbidden_for_customer?(quote.customer_id)

        render json: Quotes::Presenters::Quote.call(quote)
      end

      def send_to_customer
        result = send_quote.call(id: params[:id])

        if result.success?
          render json: Quotes::Presenters::Quote.call(result.value)
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      def approve
        quote_res = find_quote.call(id: params[:id])
        return render(json: { error: quote_res.error }, status: :not_found) if quote_res.failure?

        quote = quote_res.value
        return render_forbidden if forbidden_for_customer?(quote.customer_id)

        result = approve_quote.call(id: params[:id], quote: quote)

        if result.success?
          render json: Quotes::Presenters::Quote.call(result.value)
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      def reject
        quote_res = find_quote.call(id: params[:id])
        return render(json: { error: quote_res.error }, status: :not_found) if quote_res.failure?

        quote = quote_res.value
        return render_forbidden if forbidden_for_customer?(quote.customer_id)

        result = reject_quote.call(id: params[:id], quote: quote)

        if result.success?
          render json: Quotes::Presenters::Quote.call(result.value)
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      private

      def repository
        @repository ||= Persistence::Quotes::ActiveRecordQuoteRepository.new
      end

      def publisher
        @publisher ||= Messaging::RabbitmqPublisher.new
      end

      def find_quote
        Quotes::FindQuote.new(quote_repository: repository)
      end

      def send_quote
        Quotes::SendQuote.new(quote_repository: repository)
      end

      def approve_quote
        Quotes::ApproveQuote.new(quote_repository: repository, publisher: publisher)
      end

      def reject_quote
        Quotes::RejectQuote.new(quote_repository: repository, publisher: publisher)
      end
    end
  end
end
