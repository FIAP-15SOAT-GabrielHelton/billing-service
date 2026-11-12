class CreateQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :quotes do |t|
      # IDs de outro serviço (OS Service): sem chave estrangeira, cada serviço tem seu banco.
      t.bigint :work_order_id, null: false, index: { unique: true }
      t.bigint :customer_id, null: false
      t.string :status, null: false, default: "created"

      t.timestamps
    end

    create_table :quote_line_items do |t|
      t.references :quote, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :quantity, null: false
      t.integer :unit_price_cents, null: false

      t.timestamps
    end
  end
end
