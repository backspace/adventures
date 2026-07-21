defmodule Registrations.Landgrab.PlayerStrings do
  @moduledoc """
  Every server-originated string a participant sees in the app —
  the server-side mirror of the app's `lib/l10n/player_strings.dart`,
  under the same voice conventions (research subjects, simulation,
  Sabuk; the endgame is a mysterious outside force the organisers
  themselves don't understand).

  The words live in `priv/gettext/en/LC_MESSAGES/landgrab.po` next to
  the rest of the storyline copy — edit them there (msgids prefixed
  `app_`). This module only names the surfaces and interpolates.

  The recurring in-game vocabulary (stake / relic / …) is extracted to
  its own `term_*` msgids and injected into every lookup by `terms/0`,
  so renaming a word once there flows through every string — the server
  mirror of the app's `Terms` class. Copy below must use the `%{stake}`
  /`%{relic}` placeholders, never the literal internal "pole"/"puzzlet".

  These reach players three ways:
    * notification bodies (toast + push + history render them verbatim)
    * push titles
    * error `detail` strings for outcomes the app doesn't model with
      its own copy (it prefers server detail in those fallbacks)

  Client-modelled outcomes (already_owner, locked_out, …) show the
  app's own strings, so their controller `detail`s are diagnostics,
  not storyline surfaces — they don't appear here.
  """

  # ── Notification bodies ──────────────────────────────────────────

  def attack_body(nil, pole_name), do: phrase("app_attack_body_unknown", pole: pole_name)
  def attack_body(attacker, pole_name), do: phrase("app_attack_body", attacker: attacker, pole: pole_name)

  def pole_lost_body(nil, pole_name), do: phrase("app_pole_lost_body_unknown", pole: pole_name)
  def pole_lost_body(captor, pole_name), do: phrase("app_pole_lost_body", captor: captor, pole: pole_name)

  def puzzlet_taken_body(nil), do: phrase("app_puzzlet_taken_body_unknown")
  def puzzlet_taken_body(captor), do: phrase("app_puzzlet_taken_body", captor: captor)

  def puzzlet_withdrawn_body, do: phrase("app_puzzlet_withdrawn_body")

  def pole_contested_body(nil, pole), do: phrase("app_pole_contested_body_unknown", pole: pole)
  def pole_contested_body(team, pole), do: phrase("app_pole_contested_body", team: team, pole: pole)

  @doc "SYSTEM broadcast when the endgame withdrawal begins."
  def endgame_announcement, do: phrase("app_endgame_announcement")

  @doc "SYSTEM broadcast when the relief valve is turned on."
  def relief_enabled_body, do: phrase("app_relief_enabled_body")

  # ── Push titles ──────────────────────────────────────────────────

  def push_title("attack"), do: phrase("app_push_title_attack")
  def push_title("pole_lost"), do: phrase("app_push_title_pole_lost")
  def push_title("puzzlet_taken"), do: phrase("app_push_title_puzzlet_taken")
  def push_title("puzzlet_withdrawn"), do: phrase("app_push_title_puzzlet_withdrawn")
  def push_title("pole_contested"), do: phrase("app_push_title_pole_contested")
  def push_title(_type), do: phrase("app_push_title_default")

  # Same title, but naming the stake — so a glanced push says which one.
  def push_title(type, pole_name),
    do: phrase("app_push_title_named", title: push_title(type), pole: pole_name)

  # ── Error details the app displays verbatim ──────────────────────

  def no_team_detail, do: phrase("app_no_team_detail")
  def outside_zone_detail, do: phrase("app_outside_zone_detail")

  # Capture / answer refusals on the player's scan + attempt paths.
  # The app models most of these with its own (name-bearing) copy, so
  # these are the fallback voice for when it doesn't — kept in the
  # stake/relic/zone vocabulary so the internal "pole/puzzlet" terms
  # never reach a participant.
  def own_creation_detail, do: phrase("app_own_creation_detail")
  def already_owner_detail, do: phrase("app_already_owner_detail")
  def locked_out_detail, do: phrase("app_locked_out_detail")
  def not_active_detail, do: phrase("app_not_active_detail")
  def withdrawn_detail, do: phrase("app_withdrawn_detail")
  def already_captured_detail, do: phrase("app_already_captured_detail")
  def at_capacity_detail, do: phrase("app_at_capacity_detail")
  def stake_not_found_detail, do: phrase("app_stake_not_found_detail")
  def team_locked_out_detail, do: phrase("app_team_locked_out_detail")
  def no_relic_detail, do: phrase("app_no_relic_detail")

  # Accommodation-claim refusals (claiming a stake without solving).
  def not_prohibitive_detail, do: phrase("app_not_prohibitive_detail")
  def claim_failed_detail, do: phrase("app_claim_failed_detail")

  # Gameplay actions (scanning a stake, answering a relic) attempted
  # before the simulation's start time — the server refuses them even
  # if a client reaches the endpoint early.
  def not_started_detail, do: phrase("app_not_started_detail")

  # Answering a relic after the game has ended (its endgame window's
  # end). Stakes can still be scanned and relics viewed — only capture
  # is closed.
  def game_over_detail, do: phrase("app_game_over_detail")

  # The in-game vocabulary, injected into every lookup so any app_* string
  # can interpolate %{stake} / %{relic} / … and a rename in one place (the
  # term_* msgids) flows everywhere. Mirrors the app's `Terms` class. Real
  # bindings (a stake's name, a team name) win over these on key clash,
  # though the sets don't overlap.
  defp terms do
    [
      stake: term("term_stake"),
      stakes: term("term_stakes"),
      stakeCap: term("term_stake_cap"),
      stakesCap: term("term_stakes_cap"),
      relic: term("term_relic"),
      relics: term("term_relics"),
      relicCap: term("term_relic_cap"),
      zone: term("term_zone"),
      zones: term("term_zones"),
      zoneCap: term("term_zone_cap")
    ]
  end

  defp term(id), do: Gettext.dgettext(RegistrationsWeb.Gettext, "landgrab", id)

  defp phrase(id, bindings \\ []) do
    Gettext.dgettext(RegistrationsWeb.Gettext, "landgrab", id, Keyword.merge(terms(), bindings))
  end
end
