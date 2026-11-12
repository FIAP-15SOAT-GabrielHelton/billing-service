# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mercado Pago webhook", type: :request do
  let(:repository) { Persistence::Quotes::ActiveRecordQuoteRepository.new }
  let(:gateway) { instance_double(Integrations::MercadoPagoClient) }
  let(:publisher) { instance_double(Messaging::RabbitmqPublisher, publish: nil) }
  let(:payment) { { "id" => 99, "status" => "approved", "external_reference" => "10", "transaction_amount" => 100.0 } }

  before do
    allow(Integrations::MercadoPagoClient).to receive(:new).and_return(gateway)
    allow(Messaging::RabbitmqPublisher).to receive(:new).and_return(publisher)
    allow(gateway).to receive(:find_payment).with("99").and_return(payment)
    repository.save(Quotes::Quote.new(id: nil, work_order_id: 10, customer_id: 20, status: :approved, line_items: [
      Quotes::QuoteLineItem.new(id: nil, description: "Oil Change", quantity: 2, unit_price: 5000)
    ]))
  end

  it "confirms the payment without a JWT, trusting only what Mercado Pago's API says" do
    post "/api/v1/webhooks/mercado_pago", params: { type: "payment", data: { id: "99" } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(repository.find_by_work_order_id(10)).to be_paid
    expect(publisher).to have_received(:publish).with("payment.approved", hash_including(work_order_id: 10))
  end

  it "accepts the id in the query string (data.id), as Mercado Pago also sends it" do
    post "/api/v1/webhooks/mercado_pago?type=payment&data.id=99"

    expect(response).to have_http_status(:ok)
    expect(repository.find_by_work_order_id(10)).to be_paid
  end

  it "ignores other notification types" do
    post "/api/v1/webhooks/mercado_pago", params: { type: "merchant_order", data: { id: "5" } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(repository.find_by_work_order_id(10)).to be_approved
  end

  it "answers 422 when the payment cannot be applied, so Mercado Pago retries" do
    payment["external_reference"] = "999"

    post "/api/v1/webhooks/mercado_pago", params: { type: "payment", data: { id: "99" } }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "exposes the payment URL on the quote" do
    quote = repository.find_by_work_order_id(10)
    quote.request_payment("https://mp.test/pay/abc")
    repository.save(quote)

    get "/api/v1/work_orders/10/quote", headers: auth_headers

    expect(response.parsed_body["payment_url"]).to eq("https://mp.test/pay/abc")
  end
end
