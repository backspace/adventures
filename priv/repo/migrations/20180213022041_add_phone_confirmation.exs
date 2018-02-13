defmodule Cr2016site.Repo.Migrations.AddPhoneConfirmation do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :txt_confirmation_sent, :string
      add :txt_confirmation_received, :string
    end
  end
end
