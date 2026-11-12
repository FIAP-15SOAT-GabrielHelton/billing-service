# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::CancelQuote do
  let(:repository) { Persistence::Quotes::ActiveRecordQuoteRepository.new }
  let(:use_case) { described_class.new(quote_repository: repository) }
  let(:line_item) { Quotes::QuoteLineItem.new(id: nil, description: "Oil Change", quantity: 2, unit_price: 5000) }

  def create_quote(status)
    repository.save(
      Quotes::Quote.new(id: nil, work_order_id: 10, customer_id: 20, status: status, line_items: [ line_item ])
    )
  end

  %i[created sent approved].each do |status|
    it "cancels a quote that is #{status}" do
      create_quote(status)

      expect(use_case.call(work_order_id: 10).value.cancelled?).to be true
      expect(repository.find_by_work_order_id(10).cancelled?).to be true
    end
  end

  it "leaves a rejected quote untouched" do
    create_quote(:rejected)

    expect(use_case.call(work_order_id: 10).value.rejected?).to be true
  end

  it "is idempotent when the event is delivered twice" do
    create_quote(:approved)
    use_case.call(work_order_id: 10)

    expect(use_case.call(work_order_id: 10)).to be_success
  end

  it "succeeds when the work order has no quote" do
    expect(use_case.call(work_order_id: 999)).to be_success
  end
end
