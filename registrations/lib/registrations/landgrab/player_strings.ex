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

  @doc "SYSTEM broadcast when the endgame withdrawal begins."
  def endgame_announcement, do: phrase("app_endgame_announcement")

  # ── Push titles ──────────────────────────────────────────────────

  def push_title("attack"), do: phrase("app_push_title_attack")
  def push_title("pole_lost"), do: phrase("app_push_title_pole_lost")
  def push_title(_type), do: phrase("app_push_title_default")

  # ── Error details the app displays verbatim ──────────────────────

  def no_team_detail, do: phrase("app_no_team_detail")
  def outside_zone_detail, do: phrase("app_outside_zone_detail")

  defp phrase(id, bindings \\ []) do
    Gettext.dgettext(RegistrationsWeb.Gettext, "landgrab", id, bindings)
  end
end
