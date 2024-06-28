class GamesController < ApplicationController
  def index
    games = GameResource.all(params)
    respond_with(games)
  end

  def show
    game = GameResource.find(params)
    respond_with(game)
  end

  def create
    game = GameResource.build(params)

    if game.save
      render jsonapi: game, status: 201
    else
      render jsonapi_errors: game
    end
  end

  def update
    game = GameResource.find(params)

    if game.update_attributes
      render jsonapi: game
    else
      render jsonapi_errors: game
    end
  end

  def destroy
    game = GameResource.find(params)

    if game.destroy
      render jsonapi: { meta: {} }, status: 200
    else
      render jsonapi_errors: game
    end
  end
end
