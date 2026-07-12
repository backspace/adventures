defmodule RegistrationsWeb.LandgrabEventControllerTest do
  use Registrations.DataCase

  alias RegistrationsWeb.LandgrabEventController

  # Test config's START_TIMEZONE equivalent is Canada/Pacific
  # (config.exs); July dates are PDT, UTC-7.
  describe "localize_start_time/1" do
    test "interprets the posted naive time in the event timezone and converts to UTC" do
      %{"start_time" => converted} = LandgrabEventController.localize_start_time(%{"start_time" => "2026-07-25T10:00"})

      assert converted == ~U[2026-07-25 17:00:00Z]
    end

    test "handles a value that includes seconds" do
      %{"start_time" => converted} =
        LandgrabEventController.localize_start_time(%{"start_time" => "2026-01-25T10:00:30"})

      # January is PST, UTC-8.
      assert converted == ~U[2026-01-25 18:00:30Z]
    end

    test "passes a blank value through so the changeset can unset the field" do
      assert LandgrabEventController.localize_start_time(%{"start_time" => ""}) == %{"start_time" => ""}
    end

    test "passes an unparseable value through so the changeset reports the error" do
      assert LandgrabEventController.localize_start_time(%{"start_time" => "not a time"}) == %{
               "start_time" => "not a time"
             }
    end

    test "leaves attrs without a start_time untouched" do
      assert LandgrabEventController.localize_start_time(%{"name" => "Landgrab"}) == %{"name" => "Landgrab"}
    end
  end
end
