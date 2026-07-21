defmodule Registrations.Repo.Migrations.OwnershipEventsUsecTimestamps do
  use Ecto.Migration

  @prefix "landgrab"

  # Pole ownership is newest-wins on `ownership_events.inserted_at`, but the
  # column was second-granular (timestamp(0)): two events on the same pole
  # within one second tied, so the resolved holder was nondeterministic.
  # Widen to microsecond precision (timestamp(6)) — still without time zone,
  # so existing (second) rows are untouched — so real, near-simultaneous
  # flips order correctly. Pairs with @timestamps_opts on the schema and a
  # secondary id sort in Landgrab.latest_ownership_event_for_pole.
  def up do
    alter table(:ownership_events, prefix: @prefix) do
      modify(:inserted_at, :naive_datetime_usec)
      modify(:updated_at, :naive_datetime_usec)
    end
  end

  def down do
    alter table(:ownership_events, prefix: @prefix) do
      modify(:inserted_at, :naive_datetime)
      modify(:updated_at, :naive_datetime)
    end
  end
end
