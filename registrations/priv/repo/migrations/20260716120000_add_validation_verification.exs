defmodule Registrations.Repo.Migrations.AddValidationVerification do
  @moduledoc false
  use Ecto.Migration

  # `physically_verified` records that the validator scanned the pole's
  # barcode on-site and it matched — the strongest signal the recorded
  # pole is real and correctly located. Set on a scan-matched submit.
  def change do
    alter table("pole_validations", prefix: "landgrab") do
      add(:physically_verified, :boolean, null: false, default: false)
    end
  end
end
