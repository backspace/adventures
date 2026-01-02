defmodule RegistrationsWeb.Owner.AnswerView do
  use JSONAPI.View, type: "answers"

  def fields do
    [:label, :order, :answer, :hint]
  end

  def relationships do
    [
      specification: {RegistrationsWeb.Owner.SpecificationView, :include},
      region: {RegistrationsWeb.RegionView, :include}
    ]
  end
end
