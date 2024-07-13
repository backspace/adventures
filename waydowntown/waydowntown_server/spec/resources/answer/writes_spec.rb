require 'rails_helper'

RSpec.describe AnswerResource, type: :resource do
  describe 'creating' do
    let!(:incarnation) { create(:incarnation, answer: "the answer") }
    let!(:game) { create(:game, incarnation:) }

    let(:payload) do
      {
        data: {
          type: 'answers',
          attributes: attributes_for(:answer, answer: incarnation.answer),
          relationships: {
            game: {
              data: {
                type: 'games',
                id: game.id
              }
            }
          }
        }
      }
    end

    let!(:answer) do
      AnswerResource.build(payload)
    end

    describe 'when a game does not have a winning answer and the new answer is correct' do
      before do
        answer.save
        game.reload
      end

      it { expect(game.winner_answer).to eq(answer.data) }
    end

    describe 'when a game already has a winning answer' do
      let!(:existing_answer) { create(:answer, game: game) }

      before do
        game.update!(winner_answer: existing_answer)
      end

      it { expect(answer.save).to eq(false) }
    end
  end
end
