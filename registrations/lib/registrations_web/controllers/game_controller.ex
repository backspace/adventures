defmodule RegistrationsWeb.GameController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Game

  require Logger

  plug(JSONAPI.QueryParser,
    view: RegistrationsWeb.GameView,
    filter: ["incarnation.concept", "incarnation.id", "incarnation.placed", "incarnation.position"]
  )

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    games = Waydowntown.list_games()
    render(conn, "index.json", %{games: games, conn: conn, params: params})
  end

  def create(conn, params) do
    Logger.info("Creating game with params: #{inspect(params)}")
    incarnation_filter = get_incarnation_filter(conn.params)

    case Waydowntown.create_game(params, incarnation_filter) do
      {:ok, %Game{} = game} ->
        game = Waydowntown.get_game!(game.id)

        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.game_path(conn, :show, game))
        |> render("show.json", %{game: game, conn: conn, params: params})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", %{changeset: changeset})
    end
  end

  defp get_incarnation_filter(params) do
    case params["filter"] do
      %{"incarnation.position" => position} when is_binary(position) ->
        case String.split(position, ",") do
          [lat, lon] ->
            {latitude, _} = Float.parse(lat)
            {longitude, _} = Float.parse(lon)
            %{"position" => {latitude, longitude}}

          _ ->
            nil
        end

      %{"incarnation.placed" => placed} when placed in ["true", "false"] ->
        %{"placed" => placed}

      %{"incarnation.id" => id} when is_binary(id) ->
        %{"incarnation_id" => id}

      %{"incarnation.concept" => concept} when is_binary(concept) ->
        %{"concept" => concept}

      _ ->
        nil
    end
  end

  def show(conn, params) do
    game = Waydowntown.get_game!(params["id"])
    render(conn, "show.json", %{game: game, conn: conn, params: params})
  end

  def start(conn, %{"id" => id}) do
    game = Waydowntown.get_game!(id)

    case Waydowntown.start_game(game) do
      {:ok, started_game} ->
        render(conn, "show.json", %{game: started_game, conn: conn, params: %{}})

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: message}]})

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", message: "Unable to start the game")
    end
  end
end
