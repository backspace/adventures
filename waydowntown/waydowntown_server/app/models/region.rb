# frozen_string_literal: true

class Region < ApplicationRecord
  belongs_to :parent, optional: true, class_name: 'Region'
  has_many :children, class_name: 'Region', foreign_key: 'parent_id', dependent: :nullify, inverse_of: :parent
end
