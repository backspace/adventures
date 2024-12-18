defmodule Registrations.Waydowntown.Reveal do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"
  @foreign_key_type :binary_id

  schema "reveals" do
    belongs_to(:answer, Registrations.Waydowntown.Answer)
    belongs_to(:user, RegistrationsWeb.User)

    timestamps(updated_at: false)
  end

  def changeset(reveal, attrs) do
    reveal
    |> cast(attrs, [:answer_id, :user_id])
    |> validate_required([:answer_id, :user_id])
    |> foreign_key_constraint(:answer_id)
    |> foreign_key_constraint(:user_id)
  end
end
