class CreateLabels < ActiveRecord::Migration[8.1]
  def change
    create_table :labels do |t|
      t.string :name, null: false
      t.string :color, null: false

      t.timestamps
    end

    add_index :labels, :name, unique: true
  end
end
