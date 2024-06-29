# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'games#destroy' do
  subject(:make_request) do
    jsonapi_delete "/api/v1/games/#{game.id}"
  end

  let!(:game) { create(:game) }

  it 'cannot be called' do
    expect { make_request }.to raise_error(ActionController::RoutingError)
  end
end
