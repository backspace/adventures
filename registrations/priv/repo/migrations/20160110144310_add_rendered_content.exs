defmodule Registrations.Repo.Migrations.AddRenderedContent do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add(:rendered_content, :text)
    end
  end
end
