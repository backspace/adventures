defmodule Registrations.Repo.Migrations.AddDeviceTokens do
  @moduledoc false
  use Ecto.Migration

  def change do
    # Push-notification device tokens, one row per (device, install).
    # Registered by the app after sign-in; refreshed on FCM token
    # rotation. Lives in landgrab's schema since push is (so far) a
    # landgrab-only feature.
    create table("device_tokens", primary_key: false, prefix: "landgrab") do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references("users", prefix: "public", type: :binary_id, on_delete: :delete_all), null: false)
      add(:token, :text, null: false)
      add(:platform, :string, null: false)
      timestamps()
    end

    create(unique_index("device_tokens", [:token], prefix: "landgrab"))
    create(index("device_tokens", [:user_id], prefix: "landgrab"))
  end
end
