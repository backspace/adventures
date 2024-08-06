# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnswerResource, type: :resource do
  let(:game) { create(:game, incarnation:) }

  describe 'for a fill_in_the_blank' do
    let!(:incarnation) { create(:incarnation, concept: 'fill_in_the_blank', answer: 'the answer') }

    let(:payload) do
      {
        data: {
          type: 'answers',
          attributes: attributes_for(:answer, answer: " #{incarnation.answer.upcase} "),
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
      described_class.build(payload)
    end

    describe 'when a game does not have a winning answer and the new answer is case-insensitive correct' do
      before do
        answer.save
        game.reload
      end

      it { expect(answer.data.correct).to be(true) }
      it { expect(game.winner_answer).to eq(answer.data) }
      it { expect(game.complete).to be(true) }
    end

    describe 'when a game already has a winning answer' do
      let!(:existing_answer) { create(:answer, game:) }

      before do
        game.update!(winner_answer: existing_answer)
      end

      it { expect(answer.save).to be(false) }
    end
  end

  describe 'for bluetooth_collector' do
    let!(:incarnation) { create(:incarnation, concept: 'bluetooth_collector', answers: %w[device_a device_b]) }

    describe 'when an answer matches' do
      before do
        answer.save
        game.reload
      end

      let(:payload) do
        {
          data: {
            type: 'answers',
            attributes: attributes_for(:answer, answer: incarnation.answers.first),
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
        described_class.build(payload)
      end

      it { expect(answer.data.correct).to be(true) }
      it { expect(game.complete).to be(false) }
    end

    describe 'when an answer does not match' do
      before do
        answer.save
        game.reload
      end

      let(:payload) do
        {
          data: {
            type: 'answers',
            attributes: attributes_for(:answer, answer: 'device_c'),
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
        described_class.build(payload)
      end

      it { expect(answer.data.correct).to be(false) }
    end
  end
end
