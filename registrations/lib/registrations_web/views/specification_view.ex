defmodule RegistrationsWeb.SpecificationView do
  use JSONAPI.View, type: "specifications"

  alias RegistrationsWeb.SpecificationView

  def fields do
    [:concept, :placed, :start_description, :duration]
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
      answers: {RegistrationsWeb.AnswerView, :include}
    ]
  end
end
