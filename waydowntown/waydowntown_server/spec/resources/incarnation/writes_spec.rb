require 'rails_helper'

RSpec.describe IncarnationResource, type: :resource do
  describe 'creating' do
    let(:payload) do
      {
        data: {
          type: 'incarnations',
          attributes: attributes_for(:incarnation)
        }
      }
    end

    let(:instance) do
      IncarnationResource.build(payload)
    end

    it 'works' do
      expect {
        expect(instance.save).to eq(true), instance.errors.full_messages.to_sentence
      }.to change { Incarnation.count }.by(1)
    end
  end

  describe 'updating' do
    let!(:incarnation) { create(:incarnation) }

    let(:payload) do
      {
        data: {
          id: incarnation.id.to_s,
          type: 'incarnations',
          attributes: { } # Todo!
        }
      }
    end

    let(:instance) do
      IncarnationResource.find(payload)
    end

    xit 'works (add some attributes and enable this spec)' do
      expect {
        expect(instance.update_attributes).to eq(true)
      }.to change { incarnation.reload.updated_at }
      # .and change { incarnation.foo }.to('bar') <- example
    end
  end

  describe 'destroying' do
    let!(:incarnation) { create(:incarnation) }

    let(:instance) do
      IncarnationResource.find(id: incarnation.id)
    end

    it 'works' do
      expect {
        expect(instance.destroy).to eq(true)
      }.to change { Incarnation.count }.by(-1)
    end
  end
end
