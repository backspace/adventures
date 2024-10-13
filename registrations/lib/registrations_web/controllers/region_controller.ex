defmodule RegistrationsWeb.RegionController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  plug(JSONAPI.QueryParser,
    view: RegistrationsWeb.RegionView,
    filter: ["position"]
  )

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    regions =
      case get_position_filter(conn.params) do
        {latitude, longitude} ->
          Waydowntown.get_nearest_regions(latitude, longitude, 10)

        _ ->
          Waydowntown.list_regions()
      end

    render(conn, "index.json", %{data: regions, conn: conn, params: params})
  end

  defp get_position_filter(params) do
    case params["filter"] do
      %{"position" => position} when is_binary(position) ->
        case String.split(position, ",") do
          [lat, lon] ->
            {latitude, _} = Float.parse(lat)
            {longitude, _} = Float.parse(lon)
            {latitude, longitude}

          _ ->
            nil
        end

      _ ->
        nil
    end
  end
end
