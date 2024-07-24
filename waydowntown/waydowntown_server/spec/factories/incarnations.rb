# frozen_string_literal: true

FactoryBot.define do
  factory :incarnation do
    region

    concept { 'MyString' }
    mask { 'MyString' }
  end
end
