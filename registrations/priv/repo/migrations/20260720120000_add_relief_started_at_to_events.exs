defmodule Registrations.Repo.Migrations.AddReliefStartedAtToEvents do
  use Ecto.Migration

  # The relief valve: a supervisor-flipped mode that re-opens stakes when the
  # event runs ahead of content. Non-null = relief is on (from that moment).
  def change do
    alter table(:events, prefix: "landgrab") do
      add(:relief_started_at, :utc_datetime)
    end
  end
end
