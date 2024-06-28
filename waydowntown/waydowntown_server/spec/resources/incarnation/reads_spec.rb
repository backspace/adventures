require 'rails_helper'

RSpec.describe IncarnationResource, type: :resource do
  describe 'serialization' do
    let!(:incarnation) { create(:incarnation) }

    it 'works' do
      render
      data = jsonapi_data[0]
      expect(data.id).to eq(incarnation.id)
      expect(data.jsonapi_type).to eq('incarnations')
    end
  end

  describe 'filtering' do
    let!(:incarnation1) { create(:incarnation) }
    let!(:incarnation2) { create(:incarnation) }

    context 'by id' do
      before do
        params[:filter] = { id: { eq: incarnation2.id } }
      end

      it 'works' do
        render
        expect(d.map(&:id)).to eq([incarnation2.id])
      end
    end
  end

  describe 'sorting' do
    describe 'by id' do
      let!(:incarnation1) { create(:incarnation, id: '0551b2c7-47d9-408d-8324-299cae023ef8') }
      let!(:incarnation2) { create(:incarnation, id: '76d02d70-4b88-409b-8f0c-21ff836e0ed7') }

      context 'when ascending' do
        before do
          params[:sort] = 'id'
        end

        it 'works' do
          render
          expect(d.map(&:id)).to eq([
            incarnation1.id,
            incarnation2.id
          ])
        end
      end

      context 'when descending' do
        before do
          params[:sort] = '-id'
        end

        it 'works' do
          render
          expect(d.map(&:id)).to eq([
            incarnation2.id,
            incarnation1.id
          ])
        end
      end
    end
  end

  describe 'sideloading' do
    # ... your tests ...
  end
end
