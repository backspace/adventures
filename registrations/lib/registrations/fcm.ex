defmodule Registrations.FCM do
  @moduledoc """
  Pigeon dispatcher for Firebase Cloud Messaging (HTTP v1). Only
  supervised when `FIREBASE_SERVICE_ACCOUNT_JSON` is set — see
  `Registrations.Application.push_children/0` — so dev machines and
  tests without Firebase credentials run fine; callers must check
  `Registrations.Landgrab.Push.enabled?/0` before pushing.
  """
  use Pigeon.Dispatcher, otp_app: :registrations
end
