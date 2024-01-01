defmodule Registrations.Repo.Migrations.AddUserVoicepass do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:voicepass, :string)
    end
  end
end
