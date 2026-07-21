defmodule Registrations.Repo.Migrations.AddFinalLocationMessages do
  use Ecto.Migration

  # Bedab's stance-gated final-location messages. Deliberately DB fields
  # edited from the supervisor UI, not code/gettext strings: the final
  # location must stay changeable as the event unfolds (and the precise
  # spot is a spoiler that shouldn't live in the public repo anyway).
  def change do
    alter table(:events, prefix: "landgrab") do
      add(:final_message_joined, :text)
      add(:final_message_others, :text)
      add(:final_messages_sent_at, :utc_datetime)
    end
  end
end
