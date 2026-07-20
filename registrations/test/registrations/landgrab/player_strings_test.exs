defmodule Registrations.Landgrab.PlayerStringsTest do
  @moduledoc """
  Guards the extracted player vocabulary: every server-originated player
  string renders through the `term_*` words, no internal "pole"/"puzzlet"
  term leaks to a participant, and no interpolation placeholder survives.
  Rename a term in landgrab.po and these still pass; reintroduce a literal
  internal word and the leak guard fails.
  """
  use ExUnit.Case, async: true

  alias Registrations.Landgrab.PlayerStrings, as: PS

  # A representative rendering of every player-facing surface. Name-bearing
  # bindings use storyline-safe values, so any "pole"/"puzzlet" that turns
  # up came from the copy itself, not from an injected name.
  defp all_strings do
    name = "Blue Post"
    who = "Rival Crew"

    [
      PS.attack_body(nil, name),
      PS.attack_body(who, name),
      PS.pole_lost_body(nil, name),
      PS.pole_lost_body(who, name),
      PS.puzzlet_taken_body(nil),
      PS.puzzlet_taken_body(who),
      PS.puzzlet_withdrawn_body(),
      PS.pole_contested_body(nil, name),
      PS.pole_contested_body(who, name),
      PS.endgame_announcement(),
      PS.push_title("attack"),
      PS.push_title("pole_lost"),
      PS.push_title("puzzlet_taken"),
      PS.push_title("puzzlet_withdrawn"),
      PS.push_title("pole_contested"),
      PS.push_title("something_unmodelled"),
      PS.push_title("pole_lost", name),
      PS.no_team_detail(),
      PS.outside_zone_detail(),
      PS.own_creation_detail(),
      PS.already_owner_detail(),
      PS.locked_out_detail(),
      PS.not_active_detail(),
      PS.withdrawn_detail(),
      PS.already_captured_detail(),
      PS.at_capacity_detail(),
      PS.stake_not_found_detail(),
      PS.team_locked_out_detail(),
      PS.no_relic_detail(),
      PS.not_started_detail(),
      PS.game_over_detail()
    ]
  end

  test "no player-facing string leaks the internal pole/puzzlet vocabulary" do
    for s <- all_strings() do
      refute s =~ ~r/\b(pole|puzzlet)s?\b/i, "internal term leaked: #{inspect(s)}"
    end
  end

  test "no unresolved interpolation placeholder survives to the player" do
    for s <- all_strings() do
      refute s =~ ~r/%\{/, "unresolved placeholder in: #{inspect(s)}"
    end
  end

  test "strings render through the extracted vocabulary" do
    assert PS.push_title("pole_lost") == "Stake lost"
    assert PS.push_title("puzzlet_taken") == "Relic taken"
    assert PS.push_title("puzzlet_withdrawn") == "Relic withdrawn"
    assert PS.push_title("pole_contested") == "Stake contested"
    assert PS.game_over_detail() =~ "Stakes can still be examined"
    assert PS.game_over_detail() =~ "relics can no longer"
    assert PS.not_started_detail() =~ "Stakes can’t be claimed"
  end

  test "dynamic name bindings still interpolate the real value" do
    assert PS.attack_body("Rival Crew", "Blue Post") == "Rival Crew scanned Blue Post"
    assert PS.push_title("pole_lost", "Blue Post") == "Stake lost: Blue Post"
  end
end
