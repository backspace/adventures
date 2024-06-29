# frozen_string_literal: true

class IncarnationsController < ApplicationController
  def index
    incarnations = IncarnationResource.all(params)
    respond_with(incarnations)
  end

  def show
    incarnation = IncarnationResource.find(params)
    respond_with(incarnation)
  end

  def create
    incarnation = IncarnationResource.build(params)

    if incarnation.save
      render jsonapi: incarnation, status: :created
    else
      render jsonapi_errors: incarnation
    end
  end

  def update
    incarnation = IncarnationResource.find(params)

    if incarnation.update_attributes
      render jsonapi: incarnation
    else
      render jsonapi_errors: incarnation
    end
  end

  def destroy
    incarnation = IncarnationResource.find(params)

    if incarnation.destroy
      render jsonapi: { meta: {} }, status: :ok
    else
      render jsonapi_errors: incarnation
    end
  end
end
