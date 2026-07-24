defmodule Registrations.Repo.Migrations.AddHomepageHtmlToEvents do
  use Ecto.Migration

  # Admin-authored HTML shown on the public LANDGRAB page, below the "visiting
  # scholar Sabuk" line. Nil/blank = nothing shown. Text (not string) since it
  # can hold an arbitrary chunk of markup.
  def change do
    alter table(:events, prefix: "landgrab") do
      add(:homepage_html, :text)
    end
  end
end
