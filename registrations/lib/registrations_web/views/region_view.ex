defmodule RegistrationsWeb.RegionView do
  use JSONAPI.View, type: "regions"

  def fields do
    [:name, :description, :distance, :latitude, :longitude]
  end

  def latitude(region, _conn) do
    case region.geom do
      %Geo.Point{coordinates: {_, latitude}} ->
        "#{latitude}"

      _ ->
        nil
    end
  end

  def longitude(region, _conn) do
    case region.geom do
      %Geo.Point{coordinates: {longitude, _}} ->
        "#{longitude}"

      _ ->
        nil
    end
  end

  def relationships do
    [parent: {RegistrationsWeb.RegionView, :include}]
  end
end
