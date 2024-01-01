defmodule Registrations.Repo.Migrations.CreateUnmnemonicDevicesRecordings do
  use Ecto.Migration

  def change do
    create table(:recordings, prefix: "unmnemonic_devices", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:type, :string)
      add(:region_id, references("regions", type: :uuid))
      add(:destination_id, references("destinations", type: :uuid))
      add(:book_id, references("books", type: :uuid))
      add(:url, :string)
      add(:transcription, :text)
      add(:character_name, :string)
      add(:prompt_name, :string)
    end

    create(
      index("recordings", [:character_name, :prompt_name],
        prefix: "unmnemonic_devices",
        unique: true
      )
    )
  end
end
