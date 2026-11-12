# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::RejectQuote do
  let(:repository) { Persistence::Quotes::ActiveRecordQuoteRepository.new }
  let(:publisher) { double("publisher", publish: nil) } # rubocop:disable RSpec/VerifiedDoubles
  let(:use_case) { described_class.new(quote_repository: repository, publisher: publisher) }
  let(:line_item) { Quotes::QuoteLineItem.new(id: nil, description: "Oil Change", quantity: 2, unit_price: 5000) }
  let(:quote) do
    repository.save(
      Quotes::Quote.new(id: nil, work_order_id: 10, customer_id: 20, status: :sent, line_items: [ line_item ])
    )
  end

  it "marks the quote as rejected and publishes quote.rejected" do
    result = use_case.call(id: quote.id)

    expect(result).to be_success
    expect(repository.find(quote.id).rejected?).to be true
    expect(publisher).to have_received(:publish).with(
      "quote.rejected", { quote_id: quote.id, work_order_id: 10, total_cents: 10_000 }
    )
  end

  it "fails when the quote does not exist" do
    expect(use_case.call(id: 999_999).error).to eq("Quote not found")
  end

  it "fails on an invalid transition without publishing" do
    use_case.call(id: quote.id)

    expect(use_case.call(id: quote.id)).to be_failure
    expect(publisher).to have_received(:publish).once
  end

  it "does not persist the decision when publishing fails" do
    allow(publisher).to receive(:publish).and_raise(StandardError, "broker down")

    expect(use_case.call(id: quote.id)).to be_failure
    expect(repository.find(quote.id).sent?).to be true
  end
end
