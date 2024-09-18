defmodule RegistrationsWeb.SubmissionView do
  use JSONAPI.View, type: "submissions"

  alias RegistrationsWeb.SubmissionView

  def fields do
    [:correct, :submission, :inserted_at]
  end

  def render("show.json", %{submission: submission, conn: conn, params: params}) do
    SubmissionView.show(submission, conn, params)
  end

  def relationships do
    [answer: {RegistrationsWeb.AnswerView, :include}, run: {RegistrationsWeb.RunView, :include}]
  end
end
