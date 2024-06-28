class IncarnationResource < ApplicationResource
  attribute :id, :uuid
  attribute :concept, :string
  attribute :mask, :string
  attribute :answer, :string, only: []
end
