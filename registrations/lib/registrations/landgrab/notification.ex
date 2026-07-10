defmodule Registrations.Landgrab.Notification do
  @moduledoc """
  A message to a team. Today's callers write attack signals; the
  upcoming chat feature will write chat messages here too. See
  `landgrab.ex`'s `broadcast_attack_signal/3` for the current writer,
  and add new writers as new notification `type`s are introduced.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "notifications" do
    field(:type, :string)
    field(:body, :string)
    field(:metadata, :map)
    field(:read_at, :utc_datetime)

    belongs_to(:recipient_team, RegistrationsWeb.Team, type: :binary_id)
    belongs_to(:sender_team, RegistrationsWeb.Team, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :recipient_team_id, :sender_team_id, :body, :metadata, :read_at])
    |> validate_required([:type, :recipient_team_id, :body])
    |> assoc_constraint(:recipient_team)
    |> assoc_constraint(:sender_team)
  end
end
