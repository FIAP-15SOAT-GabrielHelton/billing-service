# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::RequestPayment do
  let(:repository) { Persistence::Quotes::ActiveRecordQuoteRepository.new }
  let(:line_item) { Quotes::QuoteLineItem.new(id: nil, description: "Oil Change", quantity: 2, unit_price: 5000) }
  let(:gateway) { instance_double(Integrations::MercadoPagoClient, create_preference: "https://mp.test/pay/abc") }
  let(:use_case) { described_class.new(quote_repository: repository, payment_gateway: gateway) }

  def create_quote(status, **attrs)
    repository.save(
      Quotes::Quote.new(id: nil, work_order_id: 10, customer_id: 20, status: status, line_items: [ line_item ], **attrs)
    )
  end


  it "creates the charge for an approved quote and stores the payment URL" do
    create_quote(:approved)

    expect(use_case.call(work_order_id: 10).value.payment_url).to eq("https://mp.test/pay/abc")
    expect(repository.find_by_work_order_id(10)).to have_attributes(payment_url: "https://mp.test/pay/abc", approved?: true)
  end

  it "does not charge twice when the event is delivered again" do
    create_quote(:approved, payment_url: "https://mp.test/pay/first")

    expect(use_case.call(work_order_id: 10)).to be_success
    expect(gateway).not_to have_received(:create_preference)
  end

  it "does not charge a quote that is not approved" do
    create_quote(:cancelled)

    expect(use_case.call(work_order_id: 10)).to be_success
    expect(gateway).not_to have_received(:create_preference)
  end

  it "succeeds when the work order has no quote" do
    expect(use_case.call(work_order_id: 999)).to be_success
  end

  it "fails when Mercado Pago is down, so the event is retried" do
    create_quote(:approved)
    allow(gateway).to receive(:create_preference).and_raise(Integrations::MercadoPagoClient::Error, "down")

    expect(use_case.call(work_order_id: 10)).to be_failure
    expect(repository.find_by_work_order_id(10).payment_url).to be_nil
  end
end
