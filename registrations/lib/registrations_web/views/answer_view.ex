defmodule RegistrationsWeb.AnswerView do
  use JSONAPI.View, type: "answers"

  alias RegistrationsWeb.AnswerView

  def fields do
    [:label]
  end

  def render("show.json", %{answer: answer, conn: conn, params: params}) do
    AnswerView.show(answer, conn, params)
  end

  def relationships do
    [specification: {RegistrationsWeb.SpecificationView, :include}]
  end
end
