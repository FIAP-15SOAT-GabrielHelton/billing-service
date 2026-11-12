# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::MercadoPagoClient do
  let(:client) { described_class.new(access_token: "TEST-token", notification_url: "https://billing.test/hook") }
  let(:http) { instance_double(Net::HTTP) }
  let(:quote) do
    Quotes::Quote.new(id: 1, work_order_id: 42, customer_id: 7, status: :approved, line_items: [
      Quotes::QuoteLineItem.new(id: 1, description: "Oil Change", quantity: 2, unit_price: 5050)
    ])
  end

  def stub_response(klass, body: "{}")
    response = klass.new("1.1", "200", "x")
    allow(response).to receive(:body).and_return(body)
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  it "creates a preference with the quote items and returns the payment URL" do
    stub_response(Net::HTTPCreated, body: { init_point: "https://mp.test/pay/abc" }.to_json)

    expect(client.create_preference(quote)).to eq("https://mp.test/pay/abc")
    expect(http).to have_received(:request) do |req|
      expect(req.path).to eq("/checkout/preferences")
      expect(req["Authorization"]).to eq("Bearer TEST-token")
      expect(JSON.parse(req.body)).to eq(
        "items" => [ { "title" => "Oil Change", "quantity" => 2, "unit_price" => 50.5, "currency_id" => "BRL" } ],
        "external_reference" => "42", "notification_url" => "https://billing.test/hook"
      )
    end
  end

  it "fetches a payment by id" do
    stub_response(Net::HTTPOK, body: { id: 99, status: "approved" }.to_json)

    expect(client.find_payment("99")).to eq("id" => 99, "status" => "approved")
    expect(http).to have_received(:request) { |req| expect(req.path).to eq("/v1/payments/99") }
  end

  it "rejects a payment id that is not numeric" do
    expect { client.find_payment("99/../x") }.to raise_error(described_class::Error, /Invalid payment id/)
  end

  it "raises when Mercado Pago answers with an error" do
    stub_response(Net::HTTPUnauthorized)

    expect { client.find_payment(99) }.to raise_error(described_class::Error, /answered 200/)
  end

  it "raises when Mercado Pago is unreachable" do
    allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)

    expect { client.find_payment(99) }.to raise_error(described_class::Error, /request failed/)
  end

  it "raises when the access token is not configured" do
    expect { described_class.new(access_token: nil).find_payment(99) }.to raise_error(described_class::Error, /not configured/)
  end
end
