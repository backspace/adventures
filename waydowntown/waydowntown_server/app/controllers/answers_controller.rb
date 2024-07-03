# frozen_string_literal: true

class AnswersController < ApplicationController
  def index
    answers = AnswerResource.all(params)
    respond_with(answers)
  end

  def show
    answer = AnswerResource.find(params)
    respond_with(answer)
  end

  def create
    answer = AnswerResource.build(params)

    if answer.save
      render jsonapi: answer, status: :created
    else
      render jsonapi_errors: answer
    end
  end
end
