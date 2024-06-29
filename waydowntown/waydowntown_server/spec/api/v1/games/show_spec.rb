# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'games#show' do
  subject(:make_request) do
    jsonapi_get "/api/v1/games/#{game.id}", params:
  end

  let(:params) { {} }

  describe 'basic fetch' do
    let!(:game) { create(:game) }

    before do
      make_request
    end

    it '200s' do
      expect(response).to have_http_status(:ok)
    end

    it 'has the correct jsonapi_type' do
      expect(d.jsonapi_type).to eq('games')
    end

    it 'has the correct id' do
      expect(d.id).to eq(game.id)
    end
  end
end
