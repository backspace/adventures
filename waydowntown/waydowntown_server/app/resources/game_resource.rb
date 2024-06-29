# frozen_string_literal: true

class GameResource < ApplicationResource
  belongs_to :incarnation

  attribute :id, :uuid

  sideloads[:incarnation]

  def create(attributes)
    game = Game.new(attributes)
    game.incarnation = Incarnation.all.sample
    game.save!
    game
  end
end
