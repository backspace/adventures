defmodule RegistrationsWeb.ParticipationView do
  use JSONAPI.View, type: "participations"

  def fields do
    [:ready_at]
  end

  def relationships do
    [run: {RegistrationsWeb.RunView, :include}, user: {RegistrationsWeb.JSONAPI.UserView, :include}]
  end
end
