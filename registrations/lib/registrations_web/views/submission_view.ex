defmodule RegistrationsWeb.SubmissionView do
  use JSONAPI.View, type: "submissions"

  def fields do
    [:correct, :submission, :inserted_at]
  end

  def relationships do
    [
      answer: {RegistrationsWeb.AnswerView, :include},
      run: {RegistrationsWeb.RunView, :include},
      creator: {RegistrationsWeb.JSONAPI.UserView, :include}
    ]
  end
end
