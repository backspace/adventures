defmodule RegistrationsWeb.GameController do
  use RegistrationsWeb, :controller

  plug(JSONAPI.QueryParser, view: RegistrationsWeb.GameView)

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Game
  require Logger

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    games = Waydowntown.list_games()
    render(conn, "index.json", %{games: games, conn: conn, params: params})
  end

  def create(conn, params) do
    Logger.info("Creating game with params: #{inspect(params)}")
    incarnation_filter = get_in(conn.params, ["incarnation_filter", "concept"])

    with {:ok, %Game{} = game} <- Waydowntown.create_game(params, incarnation_filter) do
      game = Waydowntown.get_game!(game.id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.game_path(conn, :show, game))
      |> render("show.json", %{game: game, conn: conn, params: params})
    end
  end

  def show(conn, params) do
    game = Waydowntown.get_game!(params["id"])
    render(conn, "show.json", %{game: game, conn: conn, params: params})
  end

  def update(conn, %{"id" => id, "game" => game_params}) do
    game = Waydowntown.get_game!(id)

    with {:ok, %Game{} = game} <- Waydowntown.update_game(game, game_params) do
      render(conn, "show.json", game: game)
    end
  end

  def delete(conn, %{"id" => id}) do
    game = Waydowntown.get_game!(id)

    with {:ok, %Game{}} <- Waydowntown.delete_game(game) do
      send_resp(conn, :no_content, "")
    end
  end
end
