# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'games#create' do
  subject(:make_request) do
    # FIXME: can the include be made default?
    jsonapi_post '/api/v1/games?include=incarnation', payload
  end

  let!(:incarnation) { create(:incarnation, concept: 'fill_in_the_blank', mask: 'This is a ____') }

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

    let(:sideloaded_incarnation) do
      make_request
      d.sideload(:incarnation)
    end

    it { expect { make_request }.to change(Game, :count).by(1) }

    it {
      make_request
      expect(response).to have_http_status(:created)
    }

    it { expect(sideloaded_incarnation.concept).to eq(incarnation.concept) }
    it { expect(sideloaded_incarnation.mask).to eq(incarnation.mask) }
  end
end
