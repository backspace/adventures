# frozen_string_literal: true

class Answer < ApplicationRecord
  belongs_to :game

  validate :game_cannot_have_winner, on: :create
  around_create :check_for_winner

  private

  def game_cannot_have_winner
    if game.winner_answer.present? && game.winner_answer != self
      errors.add(:game, 'already has a winner answer')
    end
  end

  def check_for_winner
    answer_found = false

    if self.game.incarnation.answer == self.answer
      answer_found = true
    end

    yield answer

    if answer_found
      self.game.winner_answer = self
      self.game.save!
    end
  end
end
