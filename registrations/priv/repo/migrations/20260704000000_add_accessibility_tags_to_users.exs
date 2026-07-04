defmodule Registrations.Repo.Migrations.AddAccessibilityTagsToUsers do
  @moduledoc """
  Participants self-identify accessibility considerations by picking
  from the same tag vocabulary used for poles / puzzlets / regions.
  Stored as a `text[]` alongside the existing free-text
  `accessibility` field, which stays as an "anything else" fallback.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:accessibility_tags, {:array, :string}, default: [], null: false)
    end
  end
end
