defmodule RegistrationsWeb.RegionView do
  use JSONAPI.View, type: "regions"

  alias RegistrationsWeb.RegionView

  def fields do
    [:name, :description, :latitude, :longitude]
  end

  def render("index.json", %{regions: regions, conn: conn, params: params}) do
    RegionView.index(regions, conn, params)
  end

  def render("show.json", %{region: region, conn: conn, params: params}) do
    RegionView.show(region, conn, params)
  end

  def relationships do
    [parent: {RegistrationsWeb.RegionView, :include}]
  end
end
