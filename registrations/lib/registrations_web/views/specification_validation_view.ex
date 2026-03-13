defmodule RegistrationsWeb.SpecificationValidationView do
  use JSONAPI.View, type: "specification-validations"

  def fields do
    [:status, :play_mode, :overall_notes]
  end

  def relationships do
    [
      specification: {RegistrationsWeb.Owner.SpecificationView, :include},
      validator: {RegistrationsWeb.JSONAPI.UserView, :include},
      assigned_by: {RegistrationsWeb.JSONAPI.UserView, :include},
      run: {RegistrationsWeb.RunView, :include},
      validation_comments: {RegistrationsWeb.ValidationCommentView, :include}
    ]
  end
end
