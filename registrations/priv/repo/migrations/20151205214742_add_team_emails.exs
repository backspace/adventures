defmodule Registrations.Repo.Migrations.AddTeamEmails do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:team_emails, :text)
    end
  end
end
