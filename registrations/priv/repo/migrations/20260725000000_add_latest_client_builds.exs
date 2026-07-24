defmodule Registrations.Repo.Migrations.AddLatestClientBuilds do
  use Ecto.Migration

  @prefix "landgrab"

  # The highest app build number the server has seen ping in, per platform
  # (iOS and Android number independently). Used to nudge older clients to
  # update — auto-tracked from the telemetry boot ping, so there's nothing to
  # maintain by hand.
  def change do
    alter table(:events, prefix: @prefix) do
      add(:latest_build_ios, :integer)
      add(:latest_build_android, :integer)
    end
  end
end
