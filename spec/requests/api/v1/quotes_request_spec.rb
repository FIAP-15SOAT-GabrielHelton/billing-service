# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Quotes", type: :request do
  let(:publisher) { instance_double(Messaging::RabbitmqPublisher, publish: nil) }
  let(:repository) { Persistence::Quotes::ActiveRecordQuoteRepository.new }
  let(:line_item) { Quotes::QuoteLineItem.new(id: nil, description: "Oil Change", quantity: 2, unit_price: 5000) }

  before { allow(Messaging::RabbitmqPublisher).to receive(:new).and_return(publisher) }

  def create_quote(status: :created)
    repository.save(
      Quotes::Quote.new(id: nil, work_order_id: 10, customer_id: 20, status: status, line_items: [ line_item ])
    )
  end

  describe "GET /api/v1/quotes/:id" do
    it "returns the quote" do
      quote = create_quote

      get "/api/v1/quotes/#{quote.id}", headers: auth_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "work_order_id" => 10, "customer_id" => 20, "status" => "created", "total" => "R$ 100.00"
      )
    end

    it "returns 404 when the quote does not exist" do
      get "/api/v1/quotes/999999", headers: auth_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without a token" do
      get "/api/v1/quotes/1", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for a token of an unknown type" do
      get "/api/v1/quotes/1", headers: bearer(type: "refresh", sub: 1), as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "lets the owning customer see the quote" do
      quote = create_quote

      get "/api/v1/quotes/#{quote.id}", headers: customer_auth_headers(customer_id: 20), as: :json

      expect(response).to have_http_status(:ok)
    end

    it "forbids another customer" do
      quote = create_quote

      get "/api/v1/quotes/#{quote.id}", headers: customer_auth_headers(customer_id: 99), as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/quotes/:id/send_to_customer" do
    it "sends the quote" do
      quote = create_quote

      patch "/api/v1/quotes/#{quote.id}/send_to_customer", headers: auth_headers, as: :json

      expect(response.parsed_body["status"]).to eq("sent")
    end

    it "forbids customers" do
      quote = create_quote

      patch "/api/v1/quotes/#{quote.id}/send_to_customer", headers: customer_auth_headers, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 422 when already sent" do
      quote = create_quote(status: :sent)

      patch "/api/v1/quotes/#{quote.id}/send_to_customer", headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  %w[approve reject].each do |action|
    event = action == "approve" ? "quote.approved" : "quote.rejected"

    describe "PATCH /api/v1/quotes/:id/#{action}" do
      it "lets the owning customer #{action} and publishes #{event}" do
        quote = create_quote(status: :sent)

        patch "/api/v1/quotes/#{quote.id}/#{action}", headers: customer_auth_headers(customer_id: 20), as: :json

        expect(response).to have_http_status(:ok)
        expect(publisher).to have_received(:publish).with(event, hash_including(work_order_id: 10))
      end

      it "forbids another customer" do
        quote = create_quote(status: :sent)

        patch "/api/v1/quotes/#{quote.id}/#{action}", headers: customer_auth_headers(customer_id: 99), as: :json

        expect(response).to have_http_status(:forbidden)
        expect(publisher).not_to have_received(:publish)
      end

      it "returns 404 when the quote does not exist" do
        patch "/api/v1/quotes/999999/#{action}", headers: auth_headers, as: :json

        expect(response).to have_http_status(:not_found)
      end

      it "returns 422 when the quote was not sent yet" do
        quote = create_quote

        patch "/api/v1/quotes/#{quote.id}/#{action}", headers: auth_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "PATCH /api/v1/webhooks/quotes/:id/#{action}" do
      it "accepts the shared webhook token and publishes #{event}" do
        quote = create_quote(status: :sent)

        patch "/api/v1/webhooks/quotes/#{quote.id}/#{action}", headers: webhook_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(publisher).to have_received(:publish).with(event, hash_including(quote_id: quote.id))
      end

      it "returns 401 with a wrong token" do
        patch "/api/v1/webhooks/quotes/1/#{action}", headers: webhook_headers(token: "wrong"), as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 422 when the quote does not exist" do
        patch "/api/v1/webhooks/quotes/999999/#{action}", headers: webhook_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
