defmodule RegistrationsWeb.JSONAPI.UserView do
  use JSONAPI.View, type: "users"

  def fields do
    [:email]
  end
end
