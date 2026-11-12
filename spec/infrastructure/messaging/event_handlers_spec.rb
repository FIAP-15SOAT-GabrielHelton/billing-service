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

  it "raises when the quote cannot be created so the message is not acked" do
    expect { handler.call(data.merge("line_items" => [ {} ])) }.to raise_error(RuntimeError)
  end
end
