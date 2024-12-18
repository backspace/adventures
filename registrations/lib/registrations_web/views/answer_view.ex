defmodule RegistrationsWeb.AnswerView do
  use JSONAPI.View, type: "answers"

  def fields do
    [:hint, :label, :order]
  end

  def get_field(field, answer, conn) do
    if field == :hint do
      if Enum.find(answer.reveals, fn reveal -> reveal.user_id == conn.assigns.current_user.id end) do
        Map.fetch!(answer, field)
      end
    else
      Map.fetch!(answer, field)
    end
  end

  def relationships do
    [specification: {RegistrationsWeb.SpecificationView, :include}]
  end
end
