# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messaging::EventHandlers do
  let(:handler) { described_class.build.fetch("work_order.diagnosed") }
  let(:data) do
    { "work_order_id" => 10, "customer_id" => 20,
      "line_items" => [ { "name" => "Oil Change", "quantity" => 2, "unit_price_cents" => 5000 } ] }
  end

  it "creates the quote for a diagnosed work order" do
    handler.call(data)

    expect(Persistence::Quotes::QuoteRecord.find_by(work_order_id: 10)).to have_attributes(customer_id: 20)
  end

  it "cancels the quote when the work order is cancelled" do
    handler.call(data)

    described_class.build.fetch("work_order.cancelled").call({ "work_order_id" => 10 })

    expect(Persistence::Quotes::QuoteRecord.find_by(work_order_id: 10).status).to eq("cancelled")
  end

  it "creates the Mercado Pago charge when the execution is completed" do
    handler.call(data)
    Persistence::Quotes::QuoteRecord.find_by(work_order_id: 10).update!(status: "approved")
    gateway = instance_double(Integrations::MercadoPagoClient, create_preference: "https://mp.test/pay/abc")

    described_class.build(payment_gateway: gateway).fetch("execution.completed").call({ "work_order_id" => 10 })

    expect(Persistence::Quotes::QuoteRecord.find_by(work_order_id: 10).payment_url).to eq("https://mp.test/pay/abc")
  end

  it "raises when the charge cannot be created so the message is retried" do
    handler.call(data)
    Persistence::Quotes::QuoteRecord.find_by(work_order_id: 10).update!(status: "approved")

    expect do
      described_class.build(payment_gateway: Integrations::MercadoPagoClient.new(access_token: nil))
                     .fetch("execution.completed").call({ "work_order_id" => 10 })
    end.to raise_error(RuntimeError, /not configured/)
  end

  it "raises when the quote cannot be created so the message is not acked" do
    expect { handler.call(data.merge("line_items" => [ {} ])) }.to raise_error(RuntimeError)
  end
end
