require 'rails_helper'

RSpec.describe "incarnations#create", type: :request do
  subject(:make_request) do
    jsonapi_post "/api/v1/incarnations", payload
  end

  describe 'basic create' do
    let(:params) do
      attributes_for(:incarnation)
    end
    let(:payload) do
      {
        data: {
          type: 'incarnations',
          attributes: params
        }
      }
    end

    it 'works' do
      expect(IncarnationResource).to receive(:build).and_call_original
      expect {
        make_request
        expect(response.status).to eq(201), response.body
      }.to change { Incarnation.count }.by(1)
    end
  end
end
