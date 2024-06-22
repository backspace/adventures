require 'rails_helper'

RSpec.describe "incarnations#destroy", type: :request do
  subject(:make_request) do
    jsonapi_delete "/api/v1/incarnations/#{incarnation.id}"
  end

  describe 'basic destroy' do
    let!(:incarnation) { create(:incarnation) }

    it 'updates the resource' do
      expect(IncarnationResource).to receive(:find).and_call_original
      expect {
        make_request
        expect(response.status).to eq(200), response.body
      }.to change { Incarnation.count }.by(-1)
      expect { incarnation.reload }
        .to raise_error(ActiveRecord::RecordNotFound)
      expect(json).to eq('meta' => {})
    end
  end
end
