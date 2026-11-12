# frozen_string_literal: true

# Tokens com as mesmas claims emitidas pelo OS Service (ver JwtAuthenticatable).
module AuthHelpers
  def auth_headers
    bearer(type: "access", sub: 1)
  end

  def customer_auth_headers(customer_id: 20)
    bearer(type: "customer_access", sub: customer_id)
  end

  def bearer(payload)
    token = ::Auth::JwtEncoder.new.encode(payload.merge(exp: 1.hour.from_now.to_i))
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
