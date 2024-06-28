class CreateIncarnations < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :incarnations, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.string :concept
      t.string :mask
      t.string :answer

      t.timestamps
    end
  end
end
