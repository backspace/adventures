defmodule Registrations.Repo.Migrations.AddThumbnailToAttachments do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:attachments, prefix: "poles") do
      add(:thumbnail_data, :binary)
      add(:thumbnail_byte_size, :integer)
    end
  end
end
