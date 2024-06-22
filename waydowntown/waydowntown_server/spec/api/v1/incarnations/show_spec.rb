require 'rails_helper'

RSpec.describe "incarnations#show", type: :request do
  let(:params) { {} }

  subject(:make_request) do
    jsonapi_get "/api/v1/incarnations/#{incarnation.id}", params: params
  end

  describe 'basic fetch' do
    let!(:incarnation) { create(:incarnation) }

    it 'works' do
      expect(IncarnationResource).to receive(:find).and_call_original
      make_request
      expect(response.status).to eq(200)
      expect(d.jsonapi_type).to eq('incarnations')
      expect(d.id).to eq(incarnation.id)
    end
  end
end
