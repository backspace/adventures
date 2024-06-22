class CreateIncarnations < ActiveRecord::Migration[7.1]
  def change
    create_table :incarnations do |t|
      t.string :concept
      t.string :mask
      t.string :answer

      t.timestamps
    end
  end
end
