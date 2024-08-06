# frozen_string_literal: true

class Incarnation < ApplicationRecord
  belongs_to :region

  def multi_answer?
    concept == 'bluetooth_collector'
  end
end
