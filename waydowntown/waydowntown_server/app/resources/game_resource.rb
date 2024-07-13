# frozen_string_literal: true

class GameResource < ApplicationResource
  belongs_to :incarnation
  has_many :answers
  belongs_to :winner_answer, resource: AnswerResource

  attribute :id, :uuid

  sideloads[:incarnation]

  # FIXME: should this be in the model? confused
  def create(attributes)
    game = Game.new(attributes)
    game.incarnation = Incarnation.all.sample
    game.save!
    game
  end
end
