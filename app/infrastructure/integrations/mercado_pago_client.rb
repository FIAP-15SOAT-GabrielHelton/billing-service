# frozen_string_literal: true

require "net/http"
require "json"

module Integrations
  # Checkout Pro do Mercado Pago: cria a cobrança (preferência) e consulta pagamentos.
  # Diferente de uma leitura opcional, aqui falha é erro: quem chama decide se tenta de novo.
  class MercadoPagoClient
    Error = Class.new(StandardError)
    BASE_URL = "https://api.mercadopago.com"

    def initialize(access_token: ENV.fetch("MERCADO_PAGO_ACCESS_TOKEN", nil),
                   notification_url: ENV.fetch("MERCADO_PAGO_NOTIFICATION_URL", nil))
      @access_token = access_token
      @notification_url = notification_url
    end

    # Retorna a URL de pagamento (init_point) para enviar ao cliente.
    def create_preference(quote)
      body = {
        items: quote.line_items.map do |item|
          { title: item.description, quantity: item.quantity, unit_price: item.unit_price.cents / 100.0, currency_id: "BRL" }
        end,
        external_reference: quote.work_order_id.to_s,
        notification_url: @notification_url.presence
      }.compact
      request(Net::HTTP::Post.new("/checkout/preferences"), body).fetch("init_point")
    end

    def find_payment(id)
      raise Error, "Invalid payment id" unless id.to_s.match?(/\A\d+\z/)

      request(Net::HTTP::Get.new("/v1/payments/#{id}"))
    end

    private

    def request(req, body = nil)
      raise Error, "MERCADO_PAGO_ACCESS_TOKEN is not configured" if @access_token.blank?

      uri = URI(BASE_URL)
      req["Authorization"] = "Bearer #{@access_token}"
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(body) if body
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 5) { |http| http.request(req) }
      raise Error, "Mercado Pago answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError, KeyError, SocketError, SystemCallError, Timeout::Error => e
      raise Error, "Mercado Pago request failed: #{e.message}"
    end
  end
end
