class CreateLabelings < ActiveRecord::Migration[8.1]
  def change
    create_table :labelings do |t|
      t.references :message, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true

      t.timestamps
    end

    add_index :labelings, [:message_id, :label_id], unique: true
  end
end
