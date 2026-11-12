class AddPaymentToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :payment_url, :string
    add_column :quotes, :payment_id, :string
  end
end
