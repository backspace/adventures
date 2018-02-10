defmodule Cr2016site.Repo.Migrations.AddTxtbeyondFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :display_size, :string
      add :txt, :boolean
      add :data, :boolean
      add :number, :string
    end
  end
end
