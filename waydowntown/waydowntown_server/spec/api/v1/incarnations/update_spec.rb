require 'rails_helper'

RSpec.describe "incarnations#update", type: :request do
  subject(:make_request) do
    jsonapi_put "/api/v1/incarnations/#{incarnation.id}", payload
  end

  describe 'basic update' do
    let!(:incarnation) { create(:incarnation) }

    let(:payload) do
      {
        data: {
          id: incarnation.id.to_s,
          type: 'incarnations',
          attributes: {
            # ... your attrs here
          }
        }
      }
    end

    # Replace 'xit' with 'it' after adding attributes
    xit 'updates the resource' do
      expect(IncarnationResource).to receive(:find).and_call_original
      expect {
        make_request
        expect(response.status).to eq(200), response.body
      }.to change { incarnation.reload.attributes }
    end
  end
end
