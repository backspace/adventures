defmodule RegistrationsWeb.SpecificationView do
  use JSONAPI.View, type: "specifications"

  def fields do
    [:concept, :start_description, :duration, :placed]
  end

  def placed(specification, _conn) do
    Registrations.Waydowntown.concept_is_placed(specification.concept)
  end

  def relationships do
    [
      region: {RegistrationsWeb.RegionView, :include},
      answers: {RegistrationsWeb.AnswerView, :include}
    ]
  end
end
