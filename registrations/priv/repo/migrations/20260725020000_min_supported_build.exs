defmodule Registrations.Repo.Migrations.MinSupportedBuild do
  use Ecto.Migration

  @prefix "landgrab"

  # Reframe the update-banner threshold from "highest build seen" (auto-tracked
  # from telemetry, and inflated by internal testers on builds external testers
  # can't install) to an admin-set MINIMUM SUPPORTED build: the app nags only
  # when it's BELOW this floor, so newer internal builds never trigger it.
  def up do
    rename(table(:events, prefix: @prefix), :latest_build_ios, to: :min_supported_build_ios)

    rename(table(:events, prefix: @prefix), :latest_build_android,
      to: :min_supported_build_android
    )

    # The carried-over values were the highest builds ever *seen*; as a floor
    # they'd nag everyone below an unavailable build. Clear them — a null floor
    # shows no banner until an admin sets a real minimum.
    execute(
      "UPDATE #{@prefix}.events SET min_supported_build_ios = NULL, min_supported_build_android = NULL"
    )
  end

  def down do
    rename(table(:events, prefix: @prefix), :min_supported_build_ios, to: :latest_build_ios)

    rename(table(:events, prefix: @prefix), :min_supported_build_android,
      to: :latest_build_android
    )
  end
end
