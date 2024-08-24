defmodule Registrations.Repo.Migrations.AddUserVoicepass do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:voicepass, :string)
    end
  end
end
