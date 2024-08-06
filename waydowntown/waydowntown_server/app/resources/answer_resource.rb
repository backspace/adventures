# frozen_string_literal: true

class AnswerResource < ApplicationResource
  belongs_to :game

  attribute :id, :uuid
  attribute :answer, :string
  attribute :correct, :boolean
end
