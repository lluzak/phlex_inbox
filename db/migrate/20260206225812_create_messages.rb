class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.string :subject, null: false
      t.text :body, null: false
      t.references :sender, null: false, foreign_key: { to_table: :contacts }
      t.references :recipient, null: false, foreign_key: { to_table: :contacts }
      t.datetime :read_at
      t.boolean :starred, default: false, null: false
      t.string :label, default: "inbox", null: false
      t.references :replied_to, foreign_key: { to_table: :messages }

      t.timestamps
    end

    add_index :messages, :label
    add_index :messages, :starred
    add_index :messages, :read_at
  end
end
