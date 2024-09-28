defmodule RegistrationsWeb.Owner.AnswerView do
  use JSONAPI.View, type: "answers"

  alias RegistrationsWeb.Owner.AnswerView

  def fields do
    [:label, :order, :answer]
  end

  def relationships do
    [specification: {RegistrationsWeb.Owner.SpecificationView, :include}]
  end
end
