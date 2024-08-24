defmodule RegistrationsWeb.AnswerView do
  use JSONAPI.View, type: "answers"

  alias RegistrationsWeb.AnswerView

  def fields do
    [:answer, :correct]
  end

  def render("show.json", %{answer: answer, conn: conn, params: params}) do
    AnswerView.show(answer, conn, params)
  end

  def relationships do
    [game: {RegistrationsWeb.GameView, :include}]
  end
end
