class CreateAnimal < ActiveRecord::Migration[6.0]
  def change
    create_table :animals do |t|
      t.text :description
    end
  end
end
