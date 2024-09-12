defmodule RegistrationsWeb.SubmissionView do
  use JSONAPI.View, type: "submissions"

  alias RegistrationsWeb.SubmissionView

  def fields do
    [:answer, :correct]
  end

  def render("show.json", %{submission: submission, conn: conn, params: params}) do
    SubmissionView.show(submission, conn, params)
  end

  def relationships do
    [run: {RegistrationsWeb.RunView, :include}]
  end
end
