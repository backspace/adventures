defmodule Registrations.Repo.Migrations.AddValidatorOnlyToPuzzlets do
  use Ecto.Migration

  def change do
    alter table("puzzlets", prefix: "landgrab") do
      # A puzzlet flagged validator_only is set aside — it shows to
      # validators and authors on their scouting/gameplay maps as
      # special (starred) but is completely invisible to regular
      # players. Author can flip it during edit; validators cannot
      # (they only observe).
      add(:validator_only, :boolean, null: false, default: false)
    end
  end
end
