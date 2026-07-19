defmodule Registrations.Landgrab.PoleNames do
  @moduledoc """
  Stable, memorable display names for stakes that have no author-given label —
  deterministic from the stake id, Heroku-app style (`adjective-noun-number`).

  Most stakes are unlabelled, and their barcode must never reach a
  participant (it's the scannable code — knowing it would let someone claim
  the stake without being there). A generated name gives each stake a
  distinct, human handle for notifications and the map without exposing
  anything scannable. The mapping is a pure function of the id, so every
  surface — and every player's device — agrees on a stake's name.

  Vocabulary adapted from the "automatic insurrection" theory-fiction slogan
  generator (github.com/johm/automatic_insurrection) — on-theme for LANDGRAB's
  settler-simulation-under-revolt framing.
  """

  # From the generator's "describing" lists, plus a few adjectival forms of
  # its other terms (offensive ← "offensive opacity", secret ← "in secret",
  # absolute ← "absolutely").
  @adjectives ~w(
    singular immanent inoperative radical offensive secret absolute
    homogenous pathetic compulsive
  )

  @nouns ~w(
    rupture insurrection crisis indifference commune multiplicity encounter
    becoming desire riot joy ecstasy misery catastrophe festival conspiracy
    destruction negation dialogue criticism scorn contempt derision structure
    temporality articulation barricade opacity
  )

  @doc """
  A stable `adjective-noun-number` name. The adjective and noun are hashed
  off the stake id (flavour); the [number] is the stake's unique ordinal, so
  the full name is guaranteed distinct across every stake even if two happen
  to share an adjective+noun.
  """
  def generate(id, number) when is_binary(id) and is_integer(number) do
    hash = :erlang.phash2(id, 1_000_000_000)
    adjective = Enum.at(@adjectives, rem(hash, length(@adjectives)))
    noun = Enum.at(@nouns, rem(div(hash, length(@adjectives)), length(@nouns)))

    "#{adjective}-#{noun}-#{number}"
  end
end
