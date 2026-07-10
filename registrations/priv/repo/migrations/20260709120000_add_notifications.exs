defmodule Registrations.Repo.Migrations.AddNotifications do
  use Ecto.Migration

  def change do
    # A generic message-to-a-team table. Today it carries attack
    # signals ("Team X just scanned your pole Y"). The upcoming chat
    # feature will land here too under a different `type`, so the
    # notification history feed can render both from a single query.
    create table("notifications", primary_key: false, prefix: "landgrab") do
      add(:id, :binary_id, primary_key: true)
      add(:type, :string, null: false)
      add(:recipient_team_id, references("teams",
        prefix: "public",
        type: :binary_id,
        on_delete: :delete_all
      ), null: false)
      # Sender is nullable so system-generated notifications ("event
      # is starting", etc.) can flow through the same table without a
      # sentinel team row.
      add(:sender_team_id, references("teams",
        prefix: "public",
        type: :binary_id,
        on_delete: :nilify_all
      ))
      add(:body, :text, null: false)
      # Typed extra payload: for attacks this holds `pole_id` and
      # `attacker_team_name`; for chat it will hold whatever the chat
      # UI needs. Keeps the table schema stable as new notification
      # types are added.
      add(:metadata, :map)
      add(:read_at, :utc_datetime)
      timestamps()
    end

    create(index("notifications", [:recipient_team_id, :inserted_at],
      prefix: "landgrab"
    ))
  end
end
