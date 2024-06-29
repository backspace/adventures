# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'games#index' do
  subject(:make_request) do
    jsonapi_get '/api/v1/games', params:
  end

  let(:params) { {} }

  describe 'basic fetch' do
    let!(:game) { create(:game) }

    before do
      make_request
    end

    it 'returns a 200 status code' do
      expect(response.status).to eq(200), response.body
    end

    it 'returns the correct jsonapi_type' do
      expect(d.map(&:jsonapi_type).uniq).to contain_exactly('games')
    end

    it 'returns the correct ids' do
      expect(d.map(&:id)).to contain_exactly(game.id)
    end
  end
end
