defmodule Registrations.Landgrab.AccessibilityTagParityTest do
  @moduledoc """
  The tag vocabulary is duplicated between the Elixir `AccessibilityTag`
  module (which the backend validates against and the /details form
  renders) and the Dart `accessibility.dart` file (which the mobile
  app's author flows use for pole / puzzlet / region chips). This test
  parses the Dart file and asserts the two lists stay in step, so an
  addition or rename can't silently drift on one side.

  Labels and explanations are also mirrored, but we don't
  machine-check those — the two runtimes surface them in very
  different contexts and cross-linking the strings would ossify what
  should stay lightly divergent (e.g. gettext on the server later
  without needing a Dart change).
  """
  use ExUnit.Case, async: true

  alias Registrations.Landgrab.AccessibilityTag

  @dart_file Path.expand("../../../../landgrab_app/lib/models/accessibility.dart", __DIR__)

  test "kAccessibilityTags in Dart matches AccessibilityTag.all/0" do
    assert File.exists?(@dart_file),
           "Expected mobile app source at #{@dart_file}; if the repo layout changed, update this path."

    dart_tags = extract_dart_tag_list(File.read!(@dart_file))

    assert dart_tags == AccessibilityTag.all(), """
    Elixir and Dart accessibility tag lists have diverged.

      Elixir (AccessibilityTag.all): #{inspect(AccessibilityTag.all())}
      Dart   (kAccessibilityTags):   #{inspect(dart_tags)}

    Update both sides — the module in
    `lib/registrations/landgrab/accessibility_tag.ex` and the const
    in `landgrab_app/lib/models/accessibility.dart`.
    """
  end

  # Pull out the `[...]` body of `const List<String> kAccessibilityTags = [...]`
  # and split on commas. Not a general Dart parser — the const is a
  # flat list of quoted string literals, so a regex is enough.
  defp extract_dart_tag_list(source) do
    [_, body] = Regex.run(~r/kAccessibilityTags\s*=\s*\[(.*?)\]/s, source)

    body
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn literal ->
      literal
      |> String.trim_leading("'")
      |> String.trim_leading("\"")
      |> String.trim_trailing("'")
      |> String.trim_trailing("\"")
    end)
  end
end
