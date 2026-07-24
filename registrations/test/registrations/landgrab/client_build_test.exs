defmodule Registrations.Landgrab.ClientBuildTest do
  use Registrations.DataCase

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Events
  alias Registrations.Repo

  defp reload, do: Repo.reload!(Events.current())

  describe "note_client_build/2" do
    test "records the first build seen per platform" do
      assert :ok = Landgrab.note_client_build("ios", 2403)
      assert :ok = Landgrab.note_client_build("android", 118)

      event = reload()
      assert event.latest_build_ios == 2403
      assert event.latest_build_android == 118
    end

    test "ratchets up but never down" do
      Landgrab.note_client_build("ios", 2403)
      Landgrab.note_client_build("ios", 2410)
      # An older client pinging in must not lower the high-water mark.
      Landgrab.note_client_build("ios", 2400)

      assert reload().latest_build_ios == 2410
    end

    test "tracks iOS and Android independently" do
      Landgrab.note_client_build("ios", 2410)
      Landgrab.note_client_build("android", 118)

      event = reload()
      assert event.latest_build_ios == 2410
      # An Android ping never touches the iOS value even though the numbers
      # diverge (Fastlane numbers each platform independently).
      assert event.latest_build_android == 118
    end

    test "ignores unknown platforms and non-positive builds" do
      assert :ok = Landgrab.note_client_build("other", 999)
      assert :ok = Landgrab.note_client_build(nil, 999)
      assert :ok = Landgrab.note_client_build("ios", 0)
      assert :ok = Landgrab.note_client_build("ios", nil)

      event = reload()
      assert is_nil(event.latest_build_ios)
      assert is_nil(event.latest_build_android)
    end
  end
end
