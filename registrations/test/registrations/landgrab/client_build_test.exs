defmodule Registrations.Landgrab.ClientBuildTest do
  @moduledoc """
  The minimum-supported-build floor that drives the app's soft "please update"
  banner. Admin-set per platform (no longer auto-tracked from telemetry, which
  let newer internal builds nag external testers who couldn't install them).
  """
  use Registrations.DataCase, async: true

  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events
  alias Registrations.Repo

  describe "minimum supported build" do
    test "the changeset accepts an admin-set floor per platform" do
      {:ok, event} =
        Events.current()
        |> Event.changeset(%{
          min_supported_build_ios: 2410,
          min_supported_build_android: 118
        })
        |> Repo.update()

      assert event.min_supported_build_ios == 2410
      assert event.min_supported_build_android == 118
    end

    test "defaults to no floor (nil), so no banner shows until one is set" do
      event = Events.current()
      assert is_nil(event.min_supported_build_ios)
      assert is_nil(event.min_supported_build_android)
    end
  end
end
