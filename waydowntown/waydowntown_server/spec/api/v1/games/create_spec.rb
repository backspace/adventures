# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'games#create' do
  subject(:make_request) do
    # FIXME: can the include be made default?
    jsonapi_post '/api/v1/games?include=incarnation,incarnation.region,incarnation.region.parent', payload
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

    let(:sideloaded_region) do
      make_request
      json['included'].find do |resource|
        resource['type'] == 'regions' and resource['id'] == sideloaded_incarnation.relationships['region']['data']['id']
      end
    end

    it { expect { make_request }.to change(Game, :count).by(1) }

    it {
      make_request
      expect(response).to have_http_status(:created)
    }

    it { expect(sideloaded_incarnation.concept).to eq(incarnation.concept) }
    it { expect(sideloaded_incarnation.mask).to eq(incarnation.mask) }

    it { expect(sideloaded_region['id']).to eq(incarnation.region.id) }
  end

  describe 'create with filter' do
    subject(:make_filtered_request) do
      jsonapi_post "/api/v1/games?include=incarnation&incarnation_filter[concept]=#{bluetooth_incarnation.concept}",
                   payload
    end

    let!(:bluetooth_incarnation) { create(:incarnation, concept: 'bluetooth_collector') }
    let(:params) { attributes_for(:game) }
    let(:payload) do
      {
        data: {
          type: 'games',
          attributes: params
        }
      }
    end

    let(:sideloaded_incarnation) do
      make_filtered_request
      d.sideload(:incarnation)
    end

    it 'returns an incarnation with the specified concept' do
      make_filtered_request
      expect(sideloaded_incarnation.concept).to eq('bluetooth_collector')
    end
  end
end
