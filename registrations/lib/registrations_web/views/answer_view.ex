defmodule RegistrationsWeb.AnswerView do
  use JSONAPI.View, type: "answers"

  def fields do
    [:label, :order]
  end

  def relationships do
    [specification: {RegistrationsWeb.SpecificationView, :include}]
  end
end
