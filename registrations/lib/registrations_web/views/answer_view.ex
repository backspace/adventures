defmodule RegistrationsWeb.AnswerView do
  use RegistrationsWeb, :view
  alias RegistrationsWeb.AnswerView

  def render("index.json", %{answers: answers}) do
    %{data: render_many(answers, AnswerView, "answer.json")}
  end

  def render("show.json", %{answer: answer}) do
    %{data: render_one(answer, AnswerView, "answer.json")}
  end

  def render("answer.json", %{answer: answer}) do
    %{
      id: answer.id,
      answer: answer.answer,
      correct: answer.correct
    }
  end
end
