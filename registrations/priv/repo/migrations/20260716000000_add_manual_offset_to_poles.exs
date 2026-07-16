defmodule Registrations.Repo.Migrations.AddManualOffsetToPoles do
  @moduledoc false
  use Ecto.Migration

  # How far (metres) an author manually dragged the pole marker away
  # from the raw GPS reading. Recorded alongside `accuracy_m` (the GPS
  # uncertainty) so validators/supervisors can see when GPS was
  # overridden. Null when the marker was never moved.
  def change do
    alter table("poles", prefix: "landgrab") do
      add(:manual_offset_m, :float)
    end
  end
end
