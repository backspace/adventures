defmodule RegistrationsWeb.ValidationCommentView do
  use JSONAPI.View, type: "validation-comments"

  def fields do
    [:field, :comment, :suggested_value, :status]
  end

  def relationships do
    [
      answer: {RegistrationsWeb.Owner.AnswerView, :include},
      specification_validation: {RegistrationsWeb.SpecificationValidationView, :include}
    ]
  end
end
