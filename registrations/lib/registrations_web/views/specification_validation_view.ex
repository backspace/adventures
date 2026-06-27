defmodule RegistrationsWeb.SpecificationValidationView do
  use JSONAPI.View, type: "specification-validations"

  alias RegistrationsWeb.JSONAPI.UserView

  def fields do
    [:status, :play_mode, :overall_notes]
  end

  def relationships do
    [
      specification: {RegistrationsWeb.Owner.SpecificationView, :include},
      validator: {UserView, :include},
      assigned_by: {UserView, :include},
      run: {RegistrationsWeb.RunView, :include},
      validation_comments: {RegistrationsWeb.ValidationCommentView, :include}
    ]
  end
end
