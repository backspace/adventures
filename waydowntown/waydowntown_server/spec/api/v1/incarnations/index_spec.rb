require 'rails_helper'

RSpec.describe "incarnations#index", type: :request do
  let(:params) { {} }

  subject(:make_request) do
    jsonapi_get "/api/v1/incarnations", params: params
  end

  describe 'basic fetch' do
    let!(:incarnation1) { create(:incarnation) }
    let!(:incarnation2) { create(:incarnation) }

    it 'works' do
      expect(IncarnationResource).to receive(:all).and_call_original
      make_request
      expect(response.status).to eq(200), response.body
      expect(d.map(&:jsonapi_type).uniq).to match_array(['incarnations'])
      expect(d.map(&:id)).to match_array([incarnation1.id, incarnation2.id])
    end
  end
end
