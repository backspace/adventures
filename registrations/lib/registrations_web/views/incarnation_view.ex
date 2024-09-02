defmodule RegistrationsWeb.IncarnationView do
  use JSONAPI.View, type: "incarnations"

  alias RegistrationsWeb.IncarnationView

  def fields do
    [:concept, :mask, :placed, :start, :answer_labels]
  end

  def answer_labels(incarnation, _conn) do
    case incarnation.concept do
      "food_court_frenzy" -> Registrations.Waydowntown.incarnation_answer_labels(incarnation)
      _ -> []
    end
  end

  def render("index.json", %{incarnations: incarnations, conn: conn, params: params}) do
    IncarnationView.index(incarnations, conn, params)
  end

  def render("show.json", %{incarnation: incarnation, conn: conn, params: params}) do
    IncarnationView.show(incarnation, conn, params)
  end

  def relationships do
    [
      region: {RegistrationsWeb.RegionView, :include},
      "region.parent": {:region, RegistrationsWeb.RegionView, :include}
    ]
  end
end
