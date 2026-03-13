defmodule RegistrationsWeb.UserRoleView do
  use JSONAPI.View, type: "user-roles"

  def fields do
    [:role]
  end

  def relationships do
    [
      user: {RegistrationsWeb.JSONAPI.UserView, :include},
      assigned_by: {RegistrationsWeb.JSONAPI.UserView, :include}
    ]
  end
end
