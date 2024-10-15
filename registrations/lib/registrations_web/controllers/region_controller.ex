defmodule RegistrationsWeb.RegionController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Region

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

  def create(conn, region_params) do
    with {:ok, %Region{} = region} <- Waydowntown.create_region(region_params) do
      conn
      |> put_status(:created)
      |> render("show.json", %{data: region})
    end
  end

  def update(conn, %{"id" => id} = region_params) do
    region = Waydowntown.get_region!(id)

    with {:ok, %Region{} = updated_region} <- Waydowntown.update_region(region, region_params) do
      render(conn, "show.json", %{data: updated_region})
    end
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
