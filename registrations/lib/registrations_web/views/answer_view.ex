defmodule RegistrationsWeb.AnswerView do
  use JSONAPI.View, type: "answers"

  def fields do
    [:has_hint, :hint, :label, :order]
  end

  def get_field(field, answer, conn) do
    cond do
      field == :hint ->
        if Enum.find(answer.reveals, fn reveal -> reveal.user_id == conn.assigns.current_user.id end) do
          Map.fetch!(answer, field)
        end

      field == :has_hint ->
        answer.hint != nil

      true ->
        Map.fetch!(answer, field)
    end
  end

  def relationships do
    [specification: {RegistrationsWeb.SpecificationView, :include}]
  end
end
