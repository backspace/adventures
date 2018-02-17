defmodule Cr2016site.Repo.Migrations.AddUserSvg do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :svg, :boolean
    end
  end
end
