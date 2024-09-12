defmodule RegistrationsWeb.SpecificationView do
  use JSONAPI.View, type: "specifications"

  alias RegistrationsWeb.SpecificationView

  def fields do
    [:concept, :placed, :answer_labels, :start, :duration]
  end

  # FIXME this will be separate
  def answer_labels(specification, _conn) do
    case specification.concept do
      "food_court_frenzy" -> Registrations.Waydowntown.specification_answer_labels(specification)
      _ -> []
    end
  end

  def render("index.json", %{specifications: specifications, conn: conn, params: params}) do
    SpecificationView.index(specifications, conn, params)
  end

  def render("show.json", %{specification: specification, conn: conn, params: params}) do
    SpecificationView.show(specification, conn, params)
  end

  def relationships do
    [
      region: {RegistrationsWeb.RegionView, :include}
    ]
  end
end
