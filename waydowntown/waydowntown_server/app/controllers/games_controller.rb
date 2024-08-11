# frozen_string_literal: true

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
    incarnation_scope = if params.dig('incarnation_filter', 'concept')
                          Incarnation.where(concept: params['incarnation_filter']['concept'])
                        else
                          Incarnation.all
                        end

    game = Game.new(incarnation: incarnation_scope.sample)

    if game.save
      render jsonapi: GameResource.find(params.merge(id: game.id)), status: :created
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
      render jsonapi: { meta: {} }, status: :ok
    else
      render jsonapi_errors: game
    end
  end
end
