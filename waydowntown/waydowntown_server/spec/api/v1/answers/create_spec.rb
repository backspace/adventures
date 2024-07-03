# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'answers#create' do
  subject(:make_request) do
    jsonapi_post '/api/v1/answers', payload
  end

  describe 'basic create' do
    let(:incarnation) { create(:incarnation) }
    let(:game) { create(:game, incarnation:) }

    let(:params) do
      attributes_for(:answer, answer: 'hey')
    end

    let(:payload) do
      {
        data: {
          type: 'answers',
          attributes: params,
          relationships: {
            game: {
              data: {
                type: 'games',
                id: game.id
              }
            }
          }
        }
      }
    end

    describe 'create' do
      before do
        make_request
      end

      it { expect(response).to have_http_status(:created) }
      it { expect(Answer.last.answer).to eq('hey') }
      it { expect(Answer.last.game).to eq(game) }
    end
  end
end
