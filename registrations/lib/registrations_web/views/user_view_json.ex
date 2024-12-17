defmodule RegistrationsWeb.JSONAPI.UserView do
  use JSONAPI.View, type: "users"

  def fields do
    [:admin, :email, :name]
  end
end
