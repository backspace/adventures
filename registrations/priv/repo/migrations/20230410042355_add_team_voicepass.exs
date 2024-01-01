defmodule Registrations.Repo.Migrations.AddTeamVoicepass do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add(:voicepass, :string)
    end
  end
end
