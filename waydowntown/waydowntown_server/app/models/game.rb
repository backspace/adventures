# frozen_string_literal: true

class Game < ApplicationRecord
  belongs_to :incarnation
  belongs_to :winner_answer, class_name: 'Answer', optional: true

  def complete
    winner_answer.present?
  end
end
