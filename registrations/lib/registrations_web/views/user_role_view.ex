defmodule RegistrationsWeb.UserRoleView do
  use JSONAPI.View, type: "user-roles"

  alias RegistrationsWeb.JSONAPI.UserView

  def fields do
    [:role]
  end

  def relationships do
    [
      user: {UserView, :include},
      assigned_by: {UserView, :include}
    ]
  end
end
