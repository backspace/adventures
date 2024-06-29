# frozen_string_literal: true

class CreateGames < ActiveRecord::Migration[7.1]
  def change
    create_table :games, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.belongs_to :incarnation, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end
  end
end
