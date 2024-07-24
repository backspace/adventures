# frozen_string_literal: true

class RegionResource < ApplicationResource
  belongs_to :parent, resource: RegionResource, optional: true

  attribute :id, :uuid
  attribute :name, :string
  attribute :description, :string
end
