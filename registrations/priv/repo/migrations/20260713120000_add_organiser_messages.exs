defmodule Registrations.Repo.Migrations.AddOrganiserMessages do
  use Ecto.Migration

  def change do
    # Storyline messages from the organisers (Sabuk / Sabuk's
    # assistant) to all participants. Rows are drafts until sent_at
    # is stamped; sending fans out one landgrab.notifications row per
    # team, which is what participants actually see.
    create table("organiser_messages", primary_key: false, prefix: "landgrab") do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:body, :text, null: false)
      add(:sender_name, :string, null: false)
      add(:sent_at, :utc_datetime)
      add(:creator_id, references("users", prefix: "public", type: :binary_id, on_delete: :nilify_all))
      timestamps()
    end
  end
end
