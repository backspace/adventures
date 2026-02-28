defmodule RegistrationsWeb.JSONAPI.UserView do
  use JSONAPI.View, type: "users"

  def fields do
    [:admin, :email, :name, :team_emails, :proposed_team_name, :risk_aversion, :team_id]
  end
end
