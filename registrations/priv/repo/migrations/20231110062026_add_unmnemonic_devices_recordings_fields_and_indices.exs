defmodule AdventureRegistrations.Repo.Migrations.AddUnmnemonicDevicesRecordingsFieldsAndIndices do
  use Ecto.Migration

  def change do
    alter table(:recordings, prefix: "unmnemonic_devices", primary_key: false) do
      add(:team_id, references("teams", prefix: "public", type: :uuid))
    end

    create(
      index("recordings", [:region_id],
        prefix: "unmnemonic_devices",
        unique: true
      )
    )

    create(
      index("recordings", [:destination_id],
        prefix: "unmnemonic_devices",
        unique: true
      )
    )

    create(
      index("recordings", [:book_id],
        prefix: "unmnemonic_devices",
        unique: true
      )
    )

    create(
      index("recordings", [:team_id],
        prefix: "unmnemonic_devices",
        unique: true
      )
    )
  end
end
