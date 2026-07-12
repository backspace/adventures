defmodule Registrations.Landgrab.DeviceToken do
  @moduledoc """
  An FCM push token for one app install. The app registers it after
  sign-in and re-registers on rotation; the server upserts on token
  conflict so a device changing hands (new login, same install) moves
  the token to the new user. Rows are deleted when FCM reports the
  token UNREGISTERED.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "device_tokens" do
    field(:token, :string)
    field(:platform, :string)

    belongs_to(:user, RegistrationsWeb.User, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(device_token, attrs) do
    device_token
    |> cast(attrs, [:token, :platform, :user_id])
    |> validate_required([:token, :platform, :user_id])
    |> validate_inclusion(:platform, ["ios", "android"])
    |> unique_constraint(:token)
  end
end
