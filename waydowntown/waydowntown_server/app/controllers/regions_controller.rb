# frozen_string_literal: true

class RegionsController < ApplicationController
  def show
    region = RegionResource.find(params)
    respond_with(region)
  end
end
