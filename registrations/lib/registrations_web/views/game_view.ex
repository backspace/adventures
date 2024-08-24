defmodule RegistrationsWeb.GameView do
  use JSONAPI.View, type: "games"
  alias RegistrationsWeb.GameView
  alias Registrations.Waydowntown

  def fields do
    [:complete, :correct_answers, :total_answers]
  end

  def hidden(game) do
    case game.incarnation.concept do
      "fill_in_the_blank" -> [:correct_answers, :total_answers]
      _ -> []
    end
  end

  def complete(game, _conn) do
    Waydowntown.get_game_progress(game).complete
  end

  def correct_answers(game, _conn) do
    Waydowntown.get_game_progress(game).correct_answers
  end

  def total_answers(game, _conn) do
    Waydowntown.get_game_progress(game).total_answers
  end

  def render("index.json", %{games: games, conn: conn, params: params}) do
    GameView.index(games, conn, params)
  end

  def render("show.json", %{game: game, conn: conn, params: params}) do
    GameView.show(game, conn, params)
  end

  def relationships do
    [
      incarnation: {RegistrationsWeb.IncarnationView, :include},
      "incarnation.region": {RegistrationsWeb.RegionView, :include},
      "incarnation.region.parent": {:region, RegistrationsWeb.RegionView, :include}
    ]
  end
end
