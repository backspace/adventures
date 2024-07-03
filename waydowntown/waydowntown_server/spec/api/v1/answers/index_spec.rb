# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'answers#index' do
  subject(:make_request) do
    jsonapi_get '/api/v1/answers', params:
  end

  let(:params) { {} }

  describe 'basic fetch' do
    let!(:game) { create(:game) }
    let!(:wrong_answer) { create(:answer, game:) }
    let!(:right_answer) { create(:answer, game:) }

    before do
      make_request
    end

    it { expect(d.map(&:id)).to contain_exactly(wrong_answer.id, right_answer.id) }
  end
end
