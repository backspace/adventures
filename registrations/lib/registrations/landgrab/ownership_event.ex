defmodule Registrations.Landgrab.OwnershipEvent do
  @moduledoc """
  Append-only, kind-tagged, newest-wins log of pole ownership / solve events —
  the generalisation of the old immutable one-row-per-puzzlet `Capture`. Two
  axes live in one table:

    * **ownership** — the newest event for a pole sets who holds it (by `kind`);
    * **solve-completion** — a solve event for `(puzzlet_id, team_id)` records
      that a team solved that puzzlet.

  `kind` is `"capture"` today (a solve that takes the pole; carries a
  `puzzlet_id`, and the pole is derived via that puzzlet). Reserved for the
  features that share this log: `"liberate"` (conspiracy — ownership to no-one)
  and `"accommodation"` (accessibility — claim without solving); those carry a
  `pole_id` and no `puzzlet_id`.

  The `(puzzlet_id, team_id)` uniqueness stops a team double-solving one puzzlet
  while allowing many teams to each solve it (the relief valve). Normal-mode
  "one capture per puzzlet globally" is enforced in `Landgrab.insert_capture`,
  not the DB, so it can be relaxed per-mode later.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Registrations.Landgrab.Puzzlet

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "landgrab"

  schema "ownership_events" do
    field(:kind, :string, default: "capture")
    field(:pole_id, :binary_id)
    belongs_to(:puzzlet, Puzzlet, type: :binary_id)
    belongs_to(:team, RegistrationsWeb.Team, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:kind, :pole_id, :puzzlet_id, :team_id])
    |> validate_required([:kind])
    |> validate_inclusion(:kind, ~w(capture liberate accommodation))
    |> assoc_constraint(:puzzlet)
    |> assoc_constraint(:team)
    |> unique_constraint([:puzzlet_id, :team_id],
      name: :ownership_events_puzzlet_team_unique
    )
  end
end
