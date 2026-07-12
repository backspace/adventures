defmodule RegistrationsWeb.AnswerKeyController do
  @moduledoc """
  Admin-only printable answer key: every pole with its barcode
  rendered as a scannable Code 128 SVG, plus each attached puzzlet's
  question and answer. Unattached puzzlets are listed at the end so
  the key is complete. Intended to be printed (or kept open on a
  phone) while checking content in the field.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet

  plug RegistrationsWeb.Plugs.Admin

  def index(conn, _params) do
    puzzlet_order = from(z in Puzzlet, order_by: [asc: z.difficulty, asc: z.inserted_at])

    poles =
      Repo.all(
        from(p in Pole,
          order_by: [asc: p.label, asc: p.barcode],
          preload: [puzzlets: ^puzzlet_order]
        )
      )

    unattached =
      Repo.all(
        from(z in Puzzlet,
          where: is_nil(z.pole_id),
          order_by: [asc: z.difficulty, asc: z.inserted_at]
        )
      )

    render(conn, "index.html",
      poles: poles,
      unattached: unattached,
      owners: owning_teams_by_pole(poles)
    )
  end

  # Map of pole id → owning Team (with users preloaded), or no entry
  # when unclaimed. One ownership query per pole (fine at event
  # scale for an admin page) plus a single team+users load.
  defp owning_teams_by_pole(poles) do
    owner_ids =
      poles
      |> Map.new(fn pole -> {pole.id, Landgrab.current_owner_team_id_for_pole(pole)} end)
      |> Enum.reject(fn {_pole_id, team_id} -> is_nil(team_id) end)
      |> Map.new()

    team_ids = owner_ids |> Map.values() |> Enum.uniq()

    teams =
      from(t in RegistrationsWeb.Team, where: t.id in ^team_ids, preload: :users)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Map.new(owner_ids, fn {pole_id, team_id} -> {pole_id, teams[team_id]} end)
  end
end
