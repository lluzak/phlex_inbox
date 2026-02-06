class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.string :name
      t.string :email
      t.string :avatar_url

      t.timestamps
    end
  end
end
