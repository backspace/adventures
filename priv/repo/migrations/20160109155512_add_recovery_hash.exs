defmodule Cr2016site.Repo.Migrations.AddDetails do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :recovery_hash, :string
    end
  end
end
