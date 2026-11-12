# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::ConfirmPayment do
  let(:repository) { Persistence::Quotes::ActiveRecordQuoteRepository.new }
  let(:line_item) { Quotes::QuoteLineItem.new(id: nil, description: "Oil Change", quantity: 2, unit_price: 5000) }
  let(:payment) { { "id" => 99, "status" => "approved", "external_reference" => "10", "transaction_amount" => 100.0 } }
  let(:gateway) { instance_double(Integrations::MercadoPagoClient, find_payment: payment) }
  let(:publisher) { instance_double(Messaging::RabbitmqPublisher, publish: nil) }
  let(:use_case) { described_class.new(quote_repository: repository, payment_gateway: gateway, publisher: publisher) }

  def create_quote(status, **attrs)
    repository.save(
      Quotes::Quote.new(id: nil, work_order_id: 10, customer_id: 20, status: status, line_items: [ line_item ], **attrs)
    )
  end


  it "marks the quote as paid and publishes payment.approved" do
    quote = create_quote(:approved)

    expect(use_case.call(payment_id: "99").value).to have_attributes(paid?: true, payment_id: "99")
    expect(publisher).to have_received(:publish).with(
      "payment.approved", { quote_id: quote.id, work_order_id: 10, payment_id: "99", amount_cents: 10_000 }
    )
  end

  it "ignores a payment that is not approved" do
    create_quote(:approved)
    payment["status"] = "rejected"

    expect(use_case.call(payment_id: "99")).to be_success
    expect(repository.find_by_work_order_id(10)).to be_approved
    expect(publisher).not_to have_received(:publish)
  end

  it "is idempotent when the webhook is delivered twice" do
    create_quote(:approved)
    use_case.call(payment_id: "99")

    expect(use_case.call(payment_id: "99")).to be_success
    expect(publisher).to have_received(:publish).once
  end

  it "refuses a payment smaller than the quote total" do
    create_quote(:approved)
    payment["transaction_amount"] = 1.0

    expect(use_case.call(payment_id: "99").error).to match(/does not cover/)
    expect(repository.find_by_work_order_id(10)).to be_approved
  end

  it "fails when the payment references an unknown work order" do
    expect(use_case.call(payment_id: "99").error).to eq("Quote not found")
  end

  it "fails for a quote that cannot be paid (e.g. cancelled)" do
    create_quote(:cancelled)

    expect(use_case.call(payment_id: "99")).to be_failure
  end

  it "does not record the payment when the event cannot be published" do
    create_quote(:approved)
    allow(publisher).to receive(:publish).and_raise(StandardError, "broker down")

    expect(use_case.call(payment_id: "99")).to be_failure
    expect(repository.find_by_work_order_id(10)).to be_approved
  end
end
