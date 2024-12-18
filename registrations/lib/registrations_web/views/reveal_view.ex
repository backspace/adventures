defmodule RegistrationsWeb.RevealView do
  use JSONAPI.View, type: "reveals"

  def fields do
    []
  end

  def relationships do
    [answer: {RegistrationsWeb.AnswerView, :include}]
  end
end
