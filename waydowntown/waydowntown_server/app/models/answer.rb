# frozen_string_literal: true

class Answer < ApplicationRecord
  belongs_to :game

  validate :game_cannot_have_winner, on: :create
  around_create :check_for_winner

  private

  def game_cannot_have_winner
    return unless game.winner_answer.present? && game.winner_answer != self

    errors.add(:game, 'already has a winner answer')
  end

  def check_for_winner
    answer_found = false

    answer_found = true if game&.incarnation&.answer&.casecmp?(answer.strip)

    yield answer

    return unless answer_found

    game.winner_answer = self
    game.save!
  end
end
