require 'rails_helper'

RSpec.describe "games#create", type: :request do
  let!(:incarnation) { create(:incarnation, concept: "fill_in_the_blank", mask: 'This is a ____') }

  subject(:make_request) do
    # FIXME can the include be made default?
    jsonapi_post "/api/v1/games?include=incarnation", payload
  end

  describe 'basic create' do
    let(:params) do
      attributes_for(:game)
    end
    let(:payload) do
      {
        data: {
          type: 'games',
          attributes: params
        }
      }
    end

    it 'works' do
      expect(GameResource).to receive(:build).and_call_original
      expect {
        make_request
        expect(response.status).to eq(201), response.body
      }.to change { Game.count }.by(1)

      sideloaded_incarnation = d.sideload(:incarnation)

      expect(sideloaded_incarnation.concept).to eq('fill_in_the_blank')
      expect(sideloaded_incarnation.mask).to eq('This is a ____')
    end
  end
end
