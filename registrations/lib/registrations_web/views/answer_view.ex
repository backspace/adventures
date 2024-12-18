defmodule RegistrationsWeb.AnswerView do
  use JSONAPI.View, type: "answers"

  def fields do
    [:hint, :label, :order]
  end

  def hidden(answer) do
    if length(answer.reveals) == 0 do
      [:hint]
    else
      []
    end
  end

  def relationships do
    [specification: {RegistrationsWeb.SpecificationView, :include}]
  end
end
