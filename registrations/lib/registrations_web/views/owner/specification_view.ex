defmodule RegistrationsWeb.Owner.SpecificationView do
  use JSONAPI.View, type: "specifications"

  def fields do
    [:concept, :start_description, :duration, :placed, :task_description]
  end

  def placed(specification, conn) do
    RegistrationsWeb.SpecificationView.placed(specification, conn)
  end

  def relationships do
    [
      region: {RegistrationsWeb.RegionView, :include},
      answers: {RegistrationsWeb.Owner.AnswerView, :include}
    ]
  end
end
