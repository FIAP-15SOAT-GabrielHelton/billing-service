# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Webhooks::Quotes', openapi_spec: 'v1/swagger.json', type: :request do
  path '/api/v1/webhooks/quotes/{id}/approve' do
    patch 'Approve quote via external webhook (status → approved, decrements stock)' do
      tags 'Quotes Webhooks'
      produces 'application/json'
      security [ { webhookToken: [] } ]
      description 'Machine-to-machine webhook for an external system to report the ' \
                   "customer's approval. Authenticated by a static shared secret in the " \
                   'X-Webhook-Token header (no user JWT).'
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'quote approved' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '401', 'missing or invalid webhook token' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '422', 'unprocessable entity (unknown quote, wrong state, or insufficient stock)' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/webhooks/quotes/{id}/reject' do
    patch 'Reject quote via external webhook (status → rejected)' do
      tags 'Quotes Webhooks'
      produces 'application/json'
      security [ { webhookToken: [] } ]
      description 'Machine-to-machine webhook for an external system to report the ' \
                   "customer's rejection. Authenticated by a static shared secret in the " \
                   'X-Webhook-Token header (no user JWT).'
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'quote rejected' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '401', 'missing or invalid webhook token' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '422', 'unprocessable entity (unknown quote or wrong state)' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/webhooks/mercado_pago' do
    post 'Mercado Pago payment notification' do
      tags 'Payment Webhooks'
      consumes 'application/json'
      produces 'application/json'
      security []
      description 'Called by Mercado Pago when a payment changes. The body is never trusted: the ' \
                  'service fetches the payment from the Mercado Pago API by its id and, if it is ' \
                  'approved and covers the quote total, marks the quote as paid and publishes ' \
                  'payment.approved. Repeated notifications are idempotent.'
      parameter name: :notification, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string, example: 'payment' },
          data: { type: :object, properties: { id: { type: :string, example: '189270743868' } } }
        }
      }

      response '200', 'notification processed (or ignored, when it is not a payment)' do
        run_test!
      end

      response '422', 'payment not found, or amount below the quote total' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
