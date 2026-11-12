# frozen_string_literal: true

module Api
  module V1
    module Webhooks
      # Notificações de pagamento do Mercado Pago. Sem JWT: quem chama é o Mercado Pago.
      # shortcut: não valida o cabeçalho x-signature; a segurança vem de consultar o pagamento
      # na API do Mercado Pago antes de aceitar. Validar a assinatura se o endpoint sofrer abuso.
      class MercadoPagoController < Api::V1::ApplicationController
        skip_before_action :authenticate!

        def create
          payment_id = params.dig(:data, :id) || params["data.id"]
          # Outros tipos de notificação (merchant_order etc.) são ignorados com 200.
          return head :ok unless params[:type] == "payment" && payment_id

          result = confirm_payment.call(payment_id: payment_id)
          # Qualquer resposta diferente de 2xx faz o Mercado Pago reenviar a notificação.
          result.success? ? head(:ok) : render(json: { error: result.error }, status: :unprocessable_entity)
        end

        private

        def confirm_payment
          Quotes::ConfirmPayment.new(
            quote_repository: Persistence::Quotes::ActiveRecordQuoteRepository.new,
            payment_gateway: Integrations::MercadoPagoClient.new,
            publisher: Messaging::RabbitmqPublisher.new
          )
        end
      end
    end
  end
end
