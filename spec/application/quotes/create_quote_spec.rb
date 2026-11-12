# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::CreateQuote do
  let(:repository) { Persistence::Quotes::ActiveRecordQuoteRepository.new }
  let(:use_case) { described_class.new(quote_repository: repository) }
  let(:line_items) do
    [ { "name" => "Oil Change", "quantity" => 2, "unit_price_cents" => 5000 },
      { "name" => "Oil filter", "quantity" => 1, "unit_price_cents" => 4500 } ]
  end

  it "creates a quote from the event payload" do
    result = use_case.call(work_order_id: 10, customer_id: 20, line_items: line_items)

    expect(result).to be_success
    expect(result.value).to have_attributes(work_order_id: 10, customer_id: 20)
    expect(result.value.total.cents).to eq(14_500)
  end

  it "is idempotent when the same event is delivered twice" do
    first = use_case.call(work_order_id: 10, customer_id: 20, line_items: line_items).value
    second = use_case.call(work_order_id: 10, customer_id: 20, line_items: line_items).value

    expect(second.id).to eq(first.id)
    expect(Persistence::Quotes::QuoteRecord.count).to eq(1)
  end

  it "fails when a line item is malformed" do
    result = use_case.call(work_order_id: 10, customer_id: 20, line_items: [ { "name" => "x" } ])

    expect(result).to be_failure
  end
end
