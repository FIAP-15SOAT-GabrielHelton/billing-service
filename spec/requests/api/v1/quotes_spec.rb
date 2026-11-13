# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Quotes', openapi_spec: 'v1/swagger.json', type: :request do
  path '/api/v1/quotes/{id}' do
    get 'Get quote by ID' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'successful' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '401', 'unauthorized' do
        run_test!
      end

      response '404', 'not found' do
        run_test!
      end
    end
  end

  path '/api/v1/quotes/{id}/send_to_customer' do
    patch 'Send quote to customer (status → sent)' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'quote sent' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '422', 'unprocessable entity' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '401', 'unauthorized' do
        run_test!
      end
    end
  end

  path '/api/v1/quotes/{id}/approve' do
    patch 'Approve quote (status → approved, decrements stock)' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'quote approved' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '422', 'unprocessable entity (e.g. insufficient stock)' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '401', 'unauthorized' do
        run_test!
      end
    end
  end

  path '/api/v1/quotes/{id}/reject' do
    patch 'Reject quote (status → rejected)' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'quote rejected' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '422', 'unprocessable entity' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '401', 'unauthorized' do
        run_test!
      end
    end
  end

  path '/api/v1/work_orders/{work_order_id}/quote' do
    get 'Get the quote of a work order (used by the OS Service to compose the work order detail)' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :work_order_id, in: :path, type: :integer, required: true

      response '200', 'successful' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '401', 'unauthorized' do
        run_test!
      end

      response '404', 'no quote for this work order' do
        run_test!
      end
    end
  end
end
