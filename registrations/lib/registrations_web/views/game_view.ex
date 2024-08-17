defmodule RegistrationsWeb.GameView do
  use JSONAPI.View, type: "games"
  alias RegistrationsWeb.GameView

  def fields do
    []
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
