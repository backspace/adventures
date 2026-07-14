defmodule Registrations.Landgrab.OrganiserMessage do
  @moduledoc """
  A storyline message from the organisers to every team. Composed
  ahead of the event (draft) or on the spot; `sent_at` is nil until
  the supervisor triggers the fan-out. The message itself is the
  source record — what participants see are the per-team
  `Notification` rows it produces on send.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "organiser_messages" do
    field(:body, :string)
    field(:sender_name, :string)
    field(:sent_at, :utc_datetime)

    belongs_to(:creator, RegistrationsWeb.User, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :sender_name, :creator_id])
    |> validate_required([:body, :sender_name])
    |> validate_length(:body, min: 1, max: 2000)
  end
end
