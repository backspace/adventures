# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  class << self
    private

    def timestamp_attributes_for_create
      super << 'inserted_at'
    end
  end
end
