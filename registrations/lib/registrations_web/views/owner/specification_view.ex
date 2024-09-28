defmodule RegistrationsWeb.Owner.SpecificationView do
  use JSONAPI.View, type: "specifications"

  alias RegistrationsWeb.Owner.SpecificationView

  def fields do
    [:concept, :start_description, :duration, :placed, :task_description]
  end

  def placed(specification, conn) do
    RegistrationsWeb.SpecificationView.placed(specification, conn)
  end

  def render("index.json", %{specifications: specifications, conn: conn, params: params}) do
    SpecificationView.index(specifications, conn, params)
  end

  def render("show.json", %{specification: specification, conn: conn, params: params}) do
    SpecificationView.show(specification, conn, params)
  end

  def relationships do
    [
      region: {RegistrationsWeb.RegionView, :include},
      answers: {RegistrationsWeb.Owner.AnswerView, :include}
    ]
  end
end
