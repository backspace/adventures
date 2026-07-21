defmodule Registrations.Landgrab do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Registrations.Landgrab.Accessibility
  alias Registrations.Landgrab.Attachment
  alias Registrations.Landgrab.Attempt
  alias Registrations.Landgrab.OwnershipEvent
  alias Registrations.Landgrab.DeviceToken
  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.OrganiserMessage
  alias Registrations.Landgrab.PlayerStrings
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.PoleNames
  alias Registrations.Landgrab.TeamPuzzlet
  alias Registrations.Landgrab.Thumbnail
  alias Registrations.Repo

  @max_attempts_per_puzzlet 3

  def max_attempts_per_puzzlet, do: @max_attempts_per_puzzlet

  # How many puzzlets a team may have active at once. 1 today
  # (deliberately, to keep teams focused on one puzzlet and discourage
  # splitting up); coded as a constant so it can be raised later.
  @active_puzzlet_capacity 1

  def active_puzzlet_capacity, do: @active_puzzlet_capacity

  def list_poles do
    Repo.all(Pole)
  end

  def get_pole!(id), do: Repo.get!(Pole, id)

  def get_pole_by_barcode(barcode) do
    Repo.get_by(Pole, barcode: barcode)
  end

  def get_puzzlet(id), do: Repo.get(Puzzlet, id)

  @doc """
  Returns each pole with its current owner team_id and locked state.
  Returns a list of `%{pole: %Pole{}, current_owner_team_id: id|nil, locked?: bool}`.
  """
  def list_poles_with_state(team_id \\ nil) do
    teams = team_style_index()
    prohibitive_ids = prohibitive_pole_ids(team_id)
    # In relief mode the map's "locked" is per-team (a stake you've drained),
    # not the global lock — so a stake others captured but you can still play
    # doesn't wrongly read as done. `team_solved` loaded once for the sweep.
    relief? = is_binary(team_id) and relief_active?()
    team_solved = if relief?, do: team_solved_puzzlet_ids(team_id), else: MapSet.new()

    playable_by_pole = if relief?, do: playable_puzzlet_ids_by_pole(), else: %{}

    Pole
    |> Repo.all()
    |> Enum.map(fn pole ->
      state =
        pole
        |> pole_with_state(teams)
        |> Map.put(:prohibitive, MapSet.member?(prohibitive_ids, pole.id))

      if relief? do
        ids = Map.get(playable_by_pole, pole.id, [])
        exhausted = ids != [] and Enum.all?(ids, &MapSet.member?(team_solved, &1))
        Map.put(state, :locked?, exhausted)
      else
        state
      end
    end)
  end

  # Playable (validated, non-VO) puzzlet ids grouped by pole — one query for the
  # relief per-team exhaustion sweep.
  defp playable_puzzlet_ids_by_pole do
    Puzzlet
    |> where([p], not is_nil(p.pole_id) and p.status == :validated and not p.validator_only)
    |> select([p], {p.pole_id, p.id})
    |> Repo.all()
    |> Enum.group_by(fn {pole_id, _} -> pole_id end, fn {_, id} -> id end)
  end

  # Pole ids where EVERY remaining (uncaptured, validated, non-validator-only)
  # puzzlet conflicts with the team's accessibility needs — so the whole team
  # can't engage anything there (they could still claim it; see the
  # accommodation path). Per-viewer, so it rides the pole-list fetch rather than
  # the team-agnostic pole_updated broadcast. Empty for a team with no declared
  # needs — the common case — which skips all the puzzlet loading.
  defp prohibitive_pole_ids(team_id) do
    needs = Accessibility.team_needs(team_id)

    if MapSet.size(needs) == 0 do
      MapSet.new()
    else
      uncaptured_playable_puzzlets_by_pole()
      |> Enum.filter(fn {_pole_id, puzzlets} -> Accessibility.prohibitive?(puzzlets, needs) end)
      |> Enum.map(fn {pole_id, _} -> pole_id end)
      |> MapSet.new()
    end
  end

  # All uncaptured, playable puzzlets grouped by pole id — same filters as
  # active_puzzlet_for_pole, across every pole in one query. Region is loaded
  # so effective-tag computation doesn't re-query per puzzlet's own row.
  defp uncaptured_playable_puzzlets_by_pole do
    # Puzzlets with a solve event (any team). Guard non-null puzzlet_id so
    # future pole-only events (liberate/accommodation) never leak a NULL into
    # the `not in` set (which would drop every row).
    captured_puzzlet_ids =
      from(c in OwnershipEvent, where: not is_nil(c.puzzlet_id), select: c.puzzlet_id)

    Puzzlet
    |> where([p], not is_nil(p.pole_id))
    |> where([p], p.status == :validated)
    |> where([p], not p.validator_only)
    |> where([p], p.id not in subquery(captured_puzzlet_ids))
    |> Repo.all()
    |> Enum.group_by(& &1.pole_id)
  end

  def pole_with_state(%Pole{} = pole, teams \\ nil) do
    teams = teams || team_style_index()
    owner_id = current_owner_team_id_for_pole(pole)
    owner = owner_id && Map.get(teams, owner_id)

    %{
      pole: pole,
      current_owner_team_id: owner_id,
      current_owner_team_name: owner && owner.name,
      current_owner_color_index: owner && owner.color_index,
      locked?: pole_locked?(pole)
    }
  end

  # Stable per-team colour slot: teams ordered by creation get 0, 1, 2, …
  # The client maps the index onto a fixed palette × pattern grid, so a team
  # keeps the same colour+pattern in every player's view. An ordinal (not a
  # stored column) — stable for the life of an event, where teams aren't
  # deleted mid-run.
  #
  # Only teams with at least one member are indexed. Teams are pre-created so
  # people can join a QR code, and many are never joined — those must not
  # consume palette slots, or the colour spread would be wasted on phantoms.
  def team_style_index do
    member_team_ids =
      RegistrationsWeb.User
      |> where([u], not is_nil(u.team_id))
      |> select([u], u.team_id)
      |> distinct(true)
      |> Repo.all()
      |> MapSet.new()

    RegistrationsWeb.Team
    |> order_by([t], asc: t.inserted_at, asc: t.id)
    |> Repo.all()
    |> Enum.filter(&MapSet.member?(member_team_ids, &1.id))
    |> Enum.with_index()
    |> Map.new(fn {team, i} -> {team.id, %{name: team.name, color_index: i}} end)
  end

  @doc """
  Returns the full payload for a barcode scan by a particular team:
  pole state plus active puzzlet (or nil if locked) and the team's
  remaining attempts on that puzzlet.
  """
  def scan_payload(barcode, team_id, user_id \\ nil, exclude \\ []) do
    case get_pole_by_barcode(barcode) do
      nil ->
        {:error, :not_found}

      pole ->
        cond do
          # "Nothing to serve here": globally captured normally, or — in relief
          # mode — every playable puzzlet already solved by THIS team (other
          # teams may still have some left).
          serving_locked?(pole, team_id) ->
            state = pole_with_state(pole)

            {:ok,
             Map.merge(state, %{
               active_puzzlet: nil,
               attempts_remaining: nil,
               previous_wrong_answers: []
             })}

          pole_owned_by_team?(pole, team_id) ->
            {:error, :already_owner, pole}

          # Checked before serving a puzzlet (and before the attack
          # signal) — a pole the boundary has passed is out of play.
          # This precedes own_creation: an out-of-play stake is out of
          # play for everyone, its author included, so the author gets
          # the out-of-play message rather than a misleading "yours".
          pole_outside_endgame_zone?(pole) ->
            {:error, :outside_zone, pole}

          user_id && pole.creator_id == user_id ->
            {:error, :own_creation, pole}

          true ->
            state = pole_with_state(pole)
            active = active_puzzlet_for_pole(pole, user_id, exclude, team_id)

            if active && team_locked_out?(active, team_id) do
              {:error, :team_locked_out, pole}
            else
              # Capacity gate: assigning refuses a new puzzlet while
              # the team is already at its limit (re-scanning the one
              # they hold just resumes). Skipped when there's no
              # puzzlet or the scanner has no team (teamless users can
              # still see a puzzlet, they just can't hold or submit
              # one) — both short-circuit to the ok payload.
              case active && team_id && assign_active_puzzlet(team_id, user_id, pole, active) do
                {:error, :at_capacity} ->
                  {:error, :at_capacity, list_active_puzzlets_for_team(team_id), pole}

                _ ->
                  {attempts_remaining, prior_wrong} =
                    case active do
                      nil ->
                        {nil, []}

                      puzzlet ->
                        {max(
                           @max_attempts_per_puzzlet -
                             team_wrong_attempts(puzzlet, team_id),
                           0
                         ), team_wrong_answers(puzzlet, team_id)}
                    end

                  maybe_signal_attack(pole, state.current_owner_team_id, team_id)

                  {:ok,
                   Map.merge(state, %{
                     active_puzzlet: active,
                     attempts_remaining: attempts_remaining,
                     previous_wrong_answers: prior_wrong,
                     contending_teams: contending_active_teams(pole.id, team_id),
                     # Which of the team's accessibility needs the served
                     # puzzlet conflicts with — [] when none. Surfaced so the
                     # app can offer "we've got it / not this one" rather than
                     # deciding for them.
                     conflict_tags: puzzlet_conflict_tags(active, team_id),
                     # Whether EVERY remaining relic here conflicts for the team
                     # — so the app can offer claiming without solving.
                     prohibitive: prohibitive_for_team?(pole, team_id)
                   })}
              end
            end
        end
    end
  end

  def create_pole(attrs) do
    %Pole{}
    |> Pole.changeset(attrs)
    |> Repo.insert()
  end

  def update_pole(%Pole{} = pole, attrs) do
    pole
    |> Pole.changeset(attrs)
    |> Repo.update()
  end

  def delete_pole(%Pole{} = pole), do: Repo.delete(pole)

  def create_attachment(attrs) do
    attrs = maybe_add_thumbnail(attrs)

    %Attachment{}
    |> Attachment.changeset(attrs)
    |> Repo.insert()
  end

  def get_attachment(id), do: Repo.get(Attachment, id)

  def get_attachment!(id), do: Repo.get!(Attachment, id)

  def delete_attachment(%Attachment{} = attachment), do: Repo.delete(attachment)

  @doc """
  Generate thumbnails for all attachments that don't have one yet. Intended
  to be called once from a release task after the migration adds the
  thumbnail columns. Safe to re-run; only processes rows still missing a
  thumbnail.
  """
  def backfill_thumbnails do
    Attachment
    |> where([a], is_nil(a.thumbnail_data))
    |> Repo.all()
    |> Enum.reduce(%{ok: 0, error: 0}, fn att, acc ->
      case Thumbnail.from_bytes(att.data) do
        {:ok, thumb} ->
          att
          |> Attachment.changeset(%{
            thumbnail_data: thumb,
            thumbnail_byte_size: byte_size(thumb)
          })
          |> Repo.update!()

          %{acc | ok: acc.ok + 1}

        _ ->
          %{acc | error: acc.error + 1}
      end
    end)
  end

  defp maybe_add_thumbnail(%{data: data} = attrs) when is_binary(data) do
    case Thumbnail.from_bytes(data) do
      {:ok, thumb} ->
        attrs
        |> Map.put(:thumbnail_data, thumb)
        |> Map.put(:thumbnail_byte_size, byte_size(thumb))

      _ ->
        attrs
    end
  end

  defp maybe_add_thumbnail(attrs), do: attrs

  def list_pole_attachment_ids(pole_id) do
    Attachment
    |> where([a], a.pole_id == ^pole_id)
    |> order_by([a], asc: a.inserted_at)
    |> select([a], a.id)
    |> Repo.all()
  end

  def list_puzzlet_attachment_ids(puzzlet_id) do
    Attachment
    |> where([a], a.puzzlet_id == ^puzzlet_id)
    |> order_by([a], asc: a.inserted_at)
    |> select([a], a.id)
    |> Repo.all()
  end

  def list_drafts_for_user(%{id: user_id}) do
    poles =
      Pole
      |> where([p], p.creator_id == ^user_id)
      |> order_by([p], desc: p.updated_at)
      |> Repo.all()

    puzzlets =
      Puzzlet
      |> where([p], p.creator_id == ^user_id)
      |> order_by([p], desc: p.updated_at)
      |> Repo.all()

    %{poles: poles, puzzlets: puzzlets}
  end

  def list_puzzlets do
    Repo.all(Puzzlet)
  end

  def list_unassigned_puzzlets do
    Repo.all(from(p in Puzzlet, where: is_nil(p.pole_id)))
  end

  @doc """
  Returns `{puzzlets, poles}` — every puzzlet and pole with a location
  inside an approximate bounding box of `radius_m` around `(lat, lng)`.

  Used by the mobile author flow's mini-map: while staking a new pole,
  the author sees which puzzlets and existing poles are around them so
  they can decide where to plant the pole (or whether to plant one at
  all — a nearby existing pole may already cover the puzzlet).

  This is a bounding-box filter, not a true radius query — cheaper and
  fine for the ~100-500m radii the map view uses. Meters convert to
  degrees using flat-earth approximations at the given latitude.
  """
  def list_nearby_authoring(lat, lng, radius_m) do
    lat_delta = radius_m / 111_000.0
    # 1° longitude ≈ 111 km × cos(lat) — narrows near the poles.
    lng_delta = radius_m / (111_000.0 * :math.cos(lat * :math.pi() / 180.0))

    lat_min = lat - lat_delta
    lat_max = lat + lat_delta
    lng_min = lng - lng_delta
    lng_max = lng + lng_delta

    puzzlets =
      Repo.all(
        from(p in Puzzlet,
          where:
            not is_nil(p.latitude) and not is_nil(p.longitude) and
              p.latitude >= ^lat_min and p.latitude <= ^lat_max and
              p.longitude >= ^lng_min and p.longitude <= ^lng_max,
          order_by: [asc: p.difficulty, asc: p.inserted_at]
        )
      )

    poles =
      Repo.all(
        from(p in Pole,
          where:
            not is_nil(p.latitude) and not is_nil(p.longitude) and
              p.latitude >= ^lat_min and p.latitude <= ^lat_max and
              p.longitude >= ^lng_min and p.longitude <= ^lng_max,
          order_by: [asc: p.inserted_at]
        )
      )

    {puzzlets, poles}
  end

  def create_puzzlet(attrs) do
    %Puzzlet{}
    |> Puzzlet.changeset(attrs)
    |> Repo.insert()
  end

  def update_puzzlet(%Puzzlet{} = puzzlet, attrs) do
    puzzlet
    |> Puzzlet.changeset(attrs)
    |> Repo.update()
  end

  def delete_puzzlet(%Puzzlet{} = puzzlet), do: Repo.delete(puzzlet)

  @doc """
  Returns the easiest validated puzzlet for the pole that has not yet been
  captured. Returns nil when the pole is locked (all puzzlets captured) or has
  no validated puzzlets assigned.

  When `user_id` is provided, puzzlets authored by that user are skipped in
  the rotation — the author silently rotates past their own work.
  """
  def active_puzzlet_for_pole(%Pole{id: pole_id}, user_id \\ nil, exclude \\ [], team_id \\ nil) do
    # Which puzzlets count as "consumed" and so aren't served:
    #   * relief mode + a team → the ones THIS team has solved (per-team pool,
    #     so a stake another team took is still playable for you);
    #   * otherwise → the globally captured ones (consume-once).
    # Guard non-null puzzlet_id so pole-only events (liberate/accommodation)
    # never leak a NULL into the `not in` set (which would drop every row).
    consumed_puzzlet_ids =
      if relief_active?() and team_id do
        from(c in OwnershipEvent,
          where: c.kind == "capture" and c.team_id == ^team_id and not is_nil(c.puzzlet_id),
          select: c.puzzlet_id
        )
      else
        from(c in OwnershipEvent, where: not is_nil(c.puzzlet_id), select: c.puzzlet_id)
      end

    query =
      Puzzlet
      |> where([p], p.pole_id == ^pole_id)
      |> where([p], p.status == :validated)
      |> where([p], not p.validator_only)
      |> where([p], p.id not in subquery(consumed_puzzlet_ids))
      |> order_by([p], asc: p.difficulty, asc: p.inserted_at)
      |> limit(1)

    query =
      if user_id do
        where(query, [p], is_nil(p.creator_id) or p.creator_id != ^user_id)
      else
        query
      end

    # Puzzlets the scanning team has explicitly declined this session ("Not
    # this one" on an accessibility conflict) — an orthogonal filter over the
    # candidate pool, so it composes with whatever else narrows it.
    query =
      case exclude do
        [] -> query
        ids -> where(query, [p], p.id not in ^ids)
      end

    Repo.one(query)
  end

  @doc """
  Whether the relief valve is on — a supervisor has re-opened stakes for
  per-team consumption because the event is running ahead of content.
  """
  def relief_active? do
    match?(%Event{relief_started_at: %DateTime{}}, Events.current())
  end

  @doc "Puzzlet ids a team has solved (a `capture` event of theirs), as a MapSet."
  def team_solved_puzzlet_ids(team_id) when is_binary(team_id) do
    from(c in OwnershipEvent,
      where: c.kind == "capture" and c.team_id == ^team_id and not is_nil(c.puzzlet_id),
      select: c.puzzlet_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def team_solved_puzzlet_ids(_), do: MapSet.new()

  @doc """
  Relief-mode "locked for you": the team has solved every playable puzzlet at
  this stake, so it has nothing left to serve them (other teams may still play
  it). Distinct from the global `pole_locked?`.
  """
  def pole_exhausted_for_team?(%Pole{id: pole_id}, team_id) when is_binary(team_id) do
    ids = playable_puzzlet_ids(pole_id)
    solved = team_solved_puzzlet_ids(team_id)
    ids != [] and Enum.all?(ids, &MapSet.member?(solved, &1))
  end

  def pole_exhausted_for_team?(_pole, _team_id), do: false

  # "Nothing left to serve here" for a scanning team: per-team exhaustion in
  # relief mode, the global lock otherwise.
  defp serving_locked?(pole, team_id) do
    if relief_active?() and is_binary(team_id) do
      pole_exhausted_for_team?(pole, team_id)
    else
      pole_locked?(pole)
    end
  end

  defp playable_puzzlet_ids(pole_id) do
    Puzzlet
    |> where([p], p.pole_id == ^pole_id and p.status == :validated and not p.validator_only)
    |> select([p], p.id)
    |> Repo.all()
  end

  @doc """
  Claim a stake **without solving** — the accommodation path for a stake that's
  prohibitive for the team (every remaining relic conflicts with a member's
  accessibility needs). Records an `accommodation` ownership event (a soft hold:
  the relics stay unsolved, so a team that *can* solve one may still take it).

  Guards mirror `record_attempt`; the prohibitive check is server-verified so a
  client can't claim a stake it could actually solve.
  """
  def accommodate_pole(%Pole{} = pole, team_id, _user_id) do
    cond do
      is_nil(team_id) ->
        {:error, :no_team}

      pole_owned_by_team?(pole, team_id) ->
        {:error, :already_owner}

      pole_outside_endgame_zone?(pole) ->
        {:error, :outside_zone}

      not prohibitive_for_team?(pole, team_id) ->
        {:error, :not_prohibitive}

      true ->
        previous_owner_id = current_owner_team_id_for_pole(pole)

        %OwnershipEvent{}
        |> OwnershipEvent.changeset(%{kind: "accommodation", pole_id: pole.id, team_id: team_id})
        |> Repo.insert()
        |> case do
          {:ok, event} ->
            broadcast_pole_update(pole, event)
            maybe_signal_pole_lost(pole, previous_owner_id, team_id)
            {:ok, pole}

          {:error, _changeset} ->
            {:error, :insert_failed}
        end
    end
  end

  @doc """
  Whether a stake is prohibitive for a team: none of its uncaptured playable
  puzzlets suits the team's union of accessibility needs. Same rule as the map
  flag; the gate for `accommodate_pole`.
  """
  def prohibitive_for_team?(%Pole{id: pole_id}, team_id) do
    needs = Accessibility.team_needs(team_id)

    MapSet.size(needs) > 0 and
      Accessibility.prohibitive?(uncaptured_playable_puzzlets(pole_id), needs)
  end

  # A pole's uncaptured, validated, non-validator-only puzzlets — the pool the
  # prohibitive check and scan-serving both draw from.
  defp uncaptured_playable_puzzlets(pole_id) do
    captured =
      from(c in OwnershipEvent, where: not is_nil(c.puzzlet_id), select: c.puzzlet_id)

    Puzzlet
    |> where([p], p.pole_id == ^pole_id and p.status == :validated and not p.validator_only)
    |> where([p], p.id not in subquery(captured))
    |> Repo.all()
  end

  # The team's accessibility needs the given puzzlet conflicts with (sorted),
  # or [] when there's no puzzlet, no team, or no conflict. Team-union needs, so
  # any one member's need shows up — matching the map flag.
  defp puzzlet_conflict_tags(nil, _team_id), do: []

  defp puzzlet_conflict_tags(%Puzzlet{} = puzzlet, team_id) do
    Accessibility.conflicting_tags(
      Accessibility.team_needs(team_id),
      Accessibility.effective_tags(puzzlet)
    )
  end

  def pole_owned_by_team?(_pole, nil), do: false

  def pole_owned_by_team?(%Pole{} = pole, team_id) do
    current_owner_team_id_for_pole(pole) == team_id
  end

  def current_owner_team_id_for_pole(%Pole{id: pole_id}) do
    # Owner = the newest ownership event for this pole, from EITHER source,
    # newest-wins across both:
    #   * capture events, tied to the pole via their puzzlet;
    #   * pole-only events (accommodation now; liberate later), tied by pole_id.
    # Its kind decides the owner: capture/accommodation → that team; liberate
    # (future) → nil (no owner).
    capture_events =
      from(c in OwnershipEvent,
        join: p in Puzzlet,
        on: p.id == c.puzzlet_id,
        where: c.kind == "capture" and p.pole_id == ^pole_id,
        select: %{team_id: c.team_id, kind: c.kind, inserted_at: c.inserted_at}
      )

    pole_events =
      from(c in OwnershipEvent,
        where: c.pole_id == ^pole_id and is_nil(c.puzzlet_id),
        select: %{team_id: c.team_id, kind: c.kind, inserted_at: c.inserted_at}
      )

    latest =
      capture_events
      |> union_all(^pole_events)
      |> subquery()
      |> order_by([e], desc: e.inserted_at)
      |> limit(1)
      |> Repo.one()

    case latest do
      nil -> nil
      %{kind: "liberate"} -> nil
      %{team_id: team_id} -> team_id
    end
  end

  def pole_locked?(%Pole{id: pole_id}) do
    # `validator_only` puzzlets don't count — they're set aside and
    # never assigned to players, so their presence shouldn't keep a
    # pole eternally unlocked, and their absence in the "captured"
    # denominator shouldn't force the pole locked prematurely.
    validated_count =
      Repo.one(
        from(p in Puzzlet,
          where:
            p.pole_id == ^pole_id and p.status == :validated and
              not p.validator_only,
          select: count(p.id)
        )
      )

    # Count DISTINCT captured puzzlets — the relaxed constraint permits several
    # teams to solve one puzzlet (relief valve), so counting rows would
    # over-count; distinct puzzlet_id keeps "captured == validated" correct.
    captured_count =
      OwnershipEvent
      |> where([c], c.kind == "capture")
      |> join(:inner, [c], p in Puzzlet, on: p.id == c.puzzlet_id)
      |> where(
        [_c, p],
        p.pole_id == ^pole_id and p.status == :validated and not p.validator_only
      )
      |> select([c, _p], count(c.puzzlet_id, :distinct))
      |> Repo.one()

    validated_count > 0 and validated_count == captured_count
  end

  @doc """
  How many times this team has answered this puzzlet incorrectly.
  Returns 0 when the user has no team.
  """
  def team_wrong_attempts(_puzzlet, nil), do: 0

  def team_wrong_attempts(%Puzzlet{id: puzzlet_id}, team_id) do
    Attempt
    |> where([a], a.puzzlet_id == ^puzzlet_id and a.correct == false)
    |> where([a], a.team_id == ^team_id)
    |> select([a], count(a.id))
    |> Repo.one()
  end

  def team_locked_out?(_puzzlet, nil), do: false

  def team_locked_out?(%Puzzlet{} = puzzlet, team_id) do
    team_wrong_attempts(puzzlet, team_id) >= @max_attempts_per_puzzlet
  end

  @doc """
  Distinct wrong answers this team has submitted for this puzzlet,
  in chronological order of first occurrence.
  """
  def team_wrong_answers(_puzzlet, nil), do: []

  def team_wrong_answers(%Puzzlet{id: puzzlet_id}, team_id) do
    Attempt
    |> where([a], a.puzzlet_id == ^puzzlet_id and a.correct == false)
    |> where([a], a.team_id == ^team_id)
    |> order_by([a], asc: a.inserted_at)
    |> select([a], a.answer_given)
    |> Repo.all()
    |> Enum.uniq()
  end

  @doc """
  Records an attempt by a team/user against a puzzlet. If the answer is
  correct and no capture exists yet, also creates the Capture row in the same
  transaction.

  Returns:
    * {:ok, %{result: :captured, attempt: attempt, capture: capture}}
    * {:ok, %{result: :incorrect, attempt: attempt, attempts_remaining: n}}
    * {:error, :already_owner}     — team is the current owner of this pole
    * {:error, :locked_out}        — team has hit max wrong attempts on puzzlet
    * {:error, :already_captured}  — another team got there first
    * {:error, changeset}
  """
  def record_attempt(%Puzzlet{} = puzzlet, team_id, user_id, answer_given) do
    pole = puzzlet.pole_id && Repo.get(Pole, puzzlet.pole_id)

    cond do
      pole && pole_owned_by_team?(pole, team_id) ->
        {:error, :already_owner}

      # Out of play for everyone once the boundary passes — takes
      # priority over own_creation so an author answering their own
      # withdrawn relic learns it's out of play, not just "yours".
      pole && pole_outside_endgame_zone?(pole) ->
        {:error, :outside_zone}

      puzzlet.creator_id == user_id ->
        {:error, :own_creation}

      pole && pole.creator_id == user_id ->
        {:error, :own_creation}

      # Pulled from play out from under an active team (supervisor withdraw,
      # or otherwise no longer validated). Their team_puzzlet row was
      # deleted, so this must precede the `not_active` check — otherwise
      # they'd get a misleading "scan the pole to begin" message.
      puzzlet.status != :validated ->
        {:error, :withdrawn}

      team_locked_out?(puzzlet, team_id) ->
        {:error, :locked_out}

      # You can only answer a puzzlet your team has actively claimed by
      # scanning its pole. No row = you never started it (or a rival's
      # capture already cleared it) — reject rather than let a direct
      # call bypass the one-at-a-time rule. Checked after `locked_out`
      # so a team that exhausted its guesses (row since abandoned) still
      # sees the locked-out message.
      not team_puzzlet_active?(team_id, puzzlet.id) ->
        {:error, :not_active}

      true ->
        correct? = answers_match?(puzzlet.answer_type, puzzlet.answer, answer_given)

        # Captured BEFORE the insert below changes ownership — this is
        # who to notify that they lost the pole.
        previous_owner_id = pole && current_owner_team_id_for_pole(pole)

        result =
          Repo.transaction(fn ->
            attempt =
              %Attempt{}
              |> Attempt.changeset(%{
                puzzlet_id: puzzlet.id,
                team_id: team_id,
                user_id: user_id,
                answer_given: answer_given,
                correct: correct?
              })
              |> Repo.insert()
              |> case do
                {:ok, attempt} ->
                  attempt

                # e.g. the team was deleted after the controller's
                # checks (rehearsal team rebuilds) — a client error
                # (422 via the controller's changeset clause), not a
                # 500.
                {:error, changeset} ->
                  Repo.rollback(changeset)
              end

            if correct? do
              case insert_capture(puzzlet.pole_id, puzzlet.id, team_id) do
                {:ok, capture} ->
                  %{result: :captured, attempt: attempt, capture: capture}

                {:error, :already_captured} ->
                  Repo.rollback(:already_captured)
              end
            else
              remaining =
                @max_attempts_per_puzzlet - team_wrong_attempts(puzzlet, team_id)

              %{result: :incorrect, attempt: attempt, attempts_remaining: max(remaining, 0)}
            end
          end)

        with {:ok, %{result: :captured, capture: capture}} <- result,
             %Pole{} = captured_pole <- pole do
          broadcast_pole_update(captured_pole, capture)
          maybe_signal_pole_lost(captured_pole, previous_owner_id, team_id)
        end

        # Resolve active-puzzlet state: a capture clears the puzzlet
        # for everyone (and notifies the rivals who were on it); an
        # incorrect answer that exhausts the team's guesses frees
        # their slot since they can no longer attempt this puzzlet.
        case result do
          {:ok, %{result: :captured}} ->
            resolve_captured_puzzlet(puzzlet, team_id)

          {:ok, %{result: :incorrect, attempts_remaining: 0}} ->
            abandon_active_puzzlet(team_id, puzzlet.id)

          _ ->
            :ok
        end

        result
    end
  end

  defp broadcast_pole_update(%Pole{} = pole, %OwnershipEvent{} = capture) do
    owner = Map.get(team_style_index(), capture.team_id)

    RegistrationsWeb.Endpoint.broadcast("landgrab:map", "pole_updated", %{
      id: pole.id,
      current_owner_team_id: capture.team_id,
      current_owner_team_name: owner && owner.name,
      current_owner_color_index: owner && owner.color_index,
      locked: pole_locked?(pole),
      captured_by_team_id: capture.team_id,
      captured_at: capture.inserted_at
    })
  end

  # Attack signals fire only when the pole is owned by someone other
  # than the scanning team, and only when a fresh signal hasn't been
  # written for the same (defender, attacker, pole) trio in the last
  # @attack_cooldown. The cooldown keeps the `notifications` history
  # from filling up with duplicate rows when an attacker retries a
  # puzzlet many times.
  @doc """
  The team's notification history, newest first. Feeds the in-app
  notifications screen; live delivery happens separately via the
  socket broadcast and push in `deliver_team_notification/6`.
  """
  def list_notifications_for_team(team_id, limit \\ 100) do
    Notification
    |> where([n], n.recipient_team_id == ^team_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def count_unread_notifications(team_id) do
    Notification
    |> where([n], n.recipient_team_id == ^team_id and is_nil(n.read_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Marks every unread notification for the team as read. Team-level on
  purpose: teams are small and share fate, so one member opening the
  history clears the badge for both. Returns the number marked.
  """
  def mark_notifications_read(team_id) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    {count, _} =
      Notification
      |> where([n], n.recipient_team_id == ^team_id and is_nil(n.read_at))
      |> Repo.update_all(set: [read_at: now, updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)])

    count
  end

  @doc """
  Set one notification's read state (per-notification swipe toggle).
  Scoped to `team_id` so a caller can only touch their team's rows.
  """
  def set_notification_read(team_id, id, read?) do
    read_at = if read?, do: DateTime.truncate(DateTime.utc_now(), :second)

    Notification
    |> where([n], n.id == ^id and n.recipient_team_id == ^team_id)
    |> Repo.update_all(set: [read_at: read_at, updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)])

    :ok
  end

  @doc """
  True when the endgame boundary has begun shrinking and `pole` lies
  outside its current radius. Locationless poles are never excluded.
  """
  def pole_outside_endgame_zone?(pole, now \\ DateTime.utc_now())

  def pole_outside_endgame_zone?(%Pole{latitude: lat, longitude: lng}, now) when is_number(lat) and is_number(lng) do
    case Event.endgame_zone(Events.current(), now) do
      nil -> false
      zone -> distance_m(lat, lng, zone.latitude, zone.longitude) > zone.radius_m
    end
  end

  def pole_outside_endgame_zone?(_pole, _now), do: false

  # Flat-earth metres at city scale — consistent with the bounding
  # boxes in list_nearby_authoring and the client's territory math.
  defp distance_m(lat1, lng1, lat2, lng2) do
    metres_per_deg_lat = 111_000.0
    metres_per_deg_lng = 111_000.0 * :math.cos(lat2 * :math.pi() / 180.0)
    dx = (lng1 - lng2) * metres_per_deg_lng
    dy = (lat1 - lat2) * metres_per_deg_lat
    :math.sqrt(dx * dx + dy * dy)
  end

  @doc """
  One-shot SYSTEM broadcast the moment the endgame boundary
  activates. Polled by `EndgameAnnouncer`; no-ops until the zone has
  begun, and `endgame_announced_at` guards against repeats across
  restarts. Returns `{:announced, team_count}` or `:noop`.
  """
  def maybe_announce_endgame(now \\ DateTime.utc_now()) do
    event = Events.current()

    if is_nil(event.endgame_announced_at) and Event.endgame_zone(event, now) do
      {:ok, message} =
        create_organiser_message(%{
          body: PlayerStrings.endgame_announcement(),
          sender_name: "SYSTEM"
        })

      {:ok, _sent, team_count} = send_organiser_message(message)

      {:ok, _event} =
        event
        |> Ecto.Changeset.change(endgame_announced_at: DateTime.truncate(now, :second))
        |> Repo.update()

      {:announced, team_count}
    else
      :noop
    end
  end

  @doc """
  Organiser messages, newest first — drafts and sent alike, for the
  supervisor's message screen.
  """
  def list_organiser_messages do
    OrganiserMessage
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  def get_organiser_message(id), do: Repo.get(OrganiserMessage, id)

  def create_organiser_message(attrs) do
    %OrganiserMessage{}
    |> OrganiserMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Fan an organiser message out to every team that has members: one
  "message" notification per team through the shared persist →
  socket → push funnel. Idempotence guard: a message can only be
  sent once. Returns `{:ok, message, team_count}`.
  """
  def send_organiser_message(%OrganiserMessage{sent_at: sent_at}) when not is_nil(sent_at) do
    {:error, :already_sent}
  end

  def send_organiser_message(%OrganiserMessage{} = message) do
    team_ids =
      RegistrationsWeb.Team
      |> join(:inner, [t], u in assoc(t, :users))
      |> select([t], t.id)
      |> distinct(true)
      |> Repo.all()

    Enum.each(team_ids, fn team_id ->
      persist_and_deliver(
        "message",
        team_id,
        nil,
        message.body,
        %{"sender_name" => message.sender_name},
        message.sender_name
      )
    end)

    {:ok, sent} =
      message
      |> Ecto.Changeset.change(sent_at: DateTime.truncate(DateTime.utc_now(), :second))
      |> Repo.update()

    {:ok, sent, length(team_ids)}
  end

  # ─── Team active puzzlets ─────────────────────────────────────────

  @doc """
  The team's active puzzlets (rich payloads: pole state, the puzzlet,
  attempts remaining, and prior wrong answers) — what the app shows
  as "in progress" and resumes into without a rescan.
  """
  def list_active_puzzlets_for_team(team_id) do
    TeamPuzzlet
    |> where([tp], tp.team_id == ^team_id)
    |> order_by([tp], asc: tp.inserted_at)
    |> Repo.all()
    |> Repo.preload([:puzzlet, :pole])
    |> Enum.map(&active_puzzlet_payload(&1, team_id))
  end

  @doc """
  Payload for one active puzzlet, matching the flat shape a scan
  returns (pole state merged with puzzlet/attempts) so the client
  renders/resumes it identically.
  """
  def active_puzzlet_payload(%TeamPuzzlet{} = tp, team_id) do
    tp.pole
    |> pole_with_state()
    |> Map.merge(%{
      active_puzzlet: tp.puzzlet,
      attempts_remaining: max(@max_attempts_per_puzzlet - team_wrong_attempts(tp.puzzlet, team_id), 0),
      previous_wrong_answers: team_wrong_answers(tp.puzzlet, team_id),
      contending_teams: contending_active_teams(tp.pole_id, team_id)
    })
  end

  @doc """
  Give this team `puzzlet` as an active puzzlet. Returns
  `{:ok, puzzlet}` on assignment, `{:already_active, puzzlet}` if they
  already held it (a resume), or `{:error, :at_capacity}` if they're
  at the active-puzzlet limit with something else.
  """
  def assign_active_puzzlet(team_id, user_id, %Pole{} = pole, %Puzzlet{} = puzzlet) do
    cond do
      team_holds_puzzlet?(team_id, puzzlet.id) ->
        {:already_active, puzzlet}

      active_puzzlet_count(team_id) >= @active_puzzlet_capacity ->
        {:error, :at_capacity}

      true ->
        %TeamPuzzlet{}
        |> TeamPuzzlet.changeset(%{
          team_id: team_id,
          puzzlet_id: puzzlet.id,
          pole_id: pole.id,
          started_by_user_id: user_id
        })
        |> Repo.insert(on_conflict: :nothing, conflict_target: [:team_id, :puzzlet_id])

        broadcast_team_puzzlets_changed(team_id)
        # Tell teams already working this pole that a rival just
        # joined the race. Only on a fresh assignment (a resume
        # returns :already_active above, so re-scans stay quiet).
        signal_pole_contested(pole, team_id)
        {:ok, puzzlet}
    end
  end

  # Distinct count of *other* teams with an active puzzlet on this
  # pole — surfaced on scan so a team knows it's contested. nil
  # excluded-team (teamless scanner) counts everyone.
  defp contending_active_teams(pole_id, exclude_team_id) do
    base = from(tp in TeamPuzzlet, where: tp.pole_id == ^pole_id, select: tp.team_id, distinct: true)
    query = if exclude_team_id, do: from(tp in base, where: tp.team_id != ^exclude_team_id), else: base
    query |> Repo.all() |> length()
  end

  defp signal_pole_contested(%Pole{} = pole, new_team_id) do
    others =
      Repo.all(
        from(tp in TeamPuzzlet,
          where: tp.pole_id == ^pole.id and tp.team_id != ^new_team_id,
          select: tp.team_id,
          distinct: true
        )
      )

    name = team_name(new_team_id)

    Enum.each(others, fn team_id ->
      persist_and_deliver(
        "pole_contested",
        team_id,
        new_team_id,
        PlayerStrings.pole_contested_body(name, pole_name(pole)),
        %{"pole_id" => pole.id, "pole_label" => pole_name(pole)},
        PlayerStrings.push_title("pole_contested")
      )
    end)

    :ok
  rescue
    error ->
      require Logger

      Logger.error("pole-contested signal failed: #{Exception.message(error)}")
      :ok
  end

  @doc """
  Assign the current active puzzlet for `pole_id` to the team without
  a barcode rescan — powers the "try the next one" offer after a
  rival captures the puzzlet you were on. Same capacity/lockout rules
  as a scan.
  """
  def assign_active_puzzlet_for_pole(team_id, user_id, pole_id) do
    pole = Repo.get(Pole, pole_id)
    active = pole && active_puzzlet_for_pole(pole, user_id)

    cond do
      is_nil(pole) -> {:error, :not_found}
      is_nil(active) -> {:error, :no_puzzlet}
      team_locked_out?(active, team_id) -> {:error, :team_locked_out}
      true -> assign_active_puzzlet(team_id, user_id, pole, active)
    end
  end

  @doc "Give up an active puzzlet, freeing the team's slot."
  def abandon_active_puzzlet(team_id, puzzlet_id) do
    {count, _} =
      TeamPuzzlet
      |> where([tp], tp.team_id == ^team_id and tp.puzzlet_id == ^puzzlet_id)
      |> Repo.delete_all()

    if count > 0, do: broadcast_team_puzzlets_changed(team_id)
    :ok
  end

  defp team_holds_puzzlet?(team_id, puzzlet_id) do
    TeamPuzzlet
    |> where([tp], tp.team_id == ^team_id and tp.puzzlet_id == ^puzzlet_id)
    |> Repo.exists?()
  end

  defp active_puzzlet_count(team_id) do
    TeamPuzzlet
    |> where([tp], tp.team_id == ^team_id)
    |> Repo.aggregate(:count)
  end

  # Whether this team is actively working on this puzzlet — i.e. they
  # scanned its pole and claimed the slot. Answering requires it.
  defp team_puzzlet_active?(team_id, puzzlet_id) do
    TeamPuzzlet
    |> where([tp], tp.team_id == ^team_id and tp.puzzlet_id == ^puzzlet_id)
    |> Repo.exists?()
  end

  # Live team sync: teammates' apps refetch their active puzzlets when
  # this fires. Guarded so a broadcast hiccup never breaks a scan.
  defp broadcast_team_puzzlets_changed(team_id) do
    RegistrationsWeb.Endpoint.broadcast("landgrab:map", "team_puzzlets_changed", %{team_id: team_id})
    :ok
  rescue
    _ -> :ok
  end

  # Captured: clear every team's active row for this puzzlet, and tell
  # the rival teams that were working it that it's gone (with whether
  # the pole has a harder puzzlet left, for the "try the next" offer).
  # A side effect of capture — must never fail the capture itself.
  defp resolve_captured_puzzlet(%Puzzlet{} = puzzlet, capturing_team_id) do
    others =
      TeamPuzzlet
      |> where([tp], tp.puzzlet_id == ^puzzlet.id and tp.team_id != ^capturing_team_id)
      |> Repo.all()

    pole = puzzlet.pole_id && Repo.get(Pole, puzzlet.pole_id)
    Enum.each(others, fn tp -> signal_puzzlet_taken(tp.team_id, capturing_team_id, puzzlet, pole) end)

    Repo.delete_all(where(TeamPuzzlet, [tp], tp.puzzlet_id == ^puzzlet.id))

    [capturing_team_id | Enum.map(others, & &1.team_id)]
    |> Enum.uniq()
    |> Enum.each(&broadcast_team_puzzlets_changed/1)

    :ok
  rescue
    error ->
      require Logger

      Logger.error("resolve_captured_puzzlet failed: #{Exception.message(error)}")
      :ok
  end

  defp signal_puzzlet_taken(recipient_team_id, capturing_team_id, %Puzzlet{} = puzzlet, pole) do
    captor_name = team_name(capturing_team_id)
    has_next = pole && active_puzzlet_for_pole(pole, nil) != nil

    persist_and_deliver(
      "puzzlet_taken",
      recipient_team_id,
      capturing_team_id,
      PlayerStrings.puzzlet_taken_body(captor_name),
      %{
        "pole_id" => pole && pole.id,
        "pole_label" => pole && pole_name(pole),
        "puzzlet_id" => puzzlet.id,
        "has_next" => !!has_next
      },
      PlayerStrings.push_title("puzzlet_taken")
    )
  end

  @doc """
  Withdraw a validated puzzlet from live play — a supervisor action taken on
  out-of-band information that a puzzlet must be pulled mid-event.

  Mirrors capture resolution, minus a captor: the puzzlet is marked
  `:withdrawn` (so it drops out of `active_puzzlet_for_pole` and can no longer
  be scanned or answered), then every team currently working it is notified
  and has its active slot freed, with the pole's next puzzlet offered — the
  same "your puzzlet was taken, try the next one" flow rivals trigger by
  capturing. Captures already made stand; withdrawal is forward-looking.
  """
  def withdraw_puzzlet(puzzlet_id) do
    result =
      Repo.transaction(fn ->
        case Repo.get(Puzzlet, puzzlet_id) do
          nil ->
            Repo.rollback(:not_found)

          %Puzzlet{status: :withdrawn} ->
            Repo.rollback(:already_withdrawn)

          %Puzzlet{} = puzzlet ->
            puzzlet
            |> Ecto.Changeset.change(status: :withdrawn)
            |> Repo.update!()
        end
      end)

    # Notify + free teams AFTER the status change commits (like capture
    # resolution) — so a client that refetches its active puzzlets on the
    # broadcast sees the freed rows, not the still-open pre-commit state.
    with {:ok, updated} <- result do
      resolve_withdrawn_puzzlet(updated)
    end

    result
  end

  # Withdrawn: notify every team working the puzzlet that it's gone (with the
  # pole's remaining-puzzlet state for the "try the next" offer), then clear
  # their active rows. Runs inside withdraw_puzzlet's transaction.
  defp resolve_withdrawn_puzzlet(%Puzzlet{} = puzzlet) do
    holders =
      TeamPuzzlet
      |> where([tp], tp.puzzlet_id == ^puzzlet.id)
      |> Repo.all()

    pole = puzzlet.pole_id && Repo.get(Pole, puzzlet.pole_id)
    # The just-withdrawn puzzlet is already excluded (status != :validated),
    # so this reflects whatever validated puzzlets remain on the pole.
    has_next = pole && active_puzzlet_for_pole(pole, nil) != nil

    Enum.each(holders, fn tp ->
      signal_puzzlet_withdrawn(tp.team_id, puzzlet, pole, has_next)
    end)

    Repo.delete_all(where(TeamPuzzlet, [tp], tp.puzzlet_id == ^puzzlet.id))

    holders
    |> Enum.map(& &1.team_id)
    |> Enum.uniq()
    |> Enum.each(&broadcast_team_puzzlets_changed/1)

    :ok
  end

  defp signal_puzzlet_withdrawn(recipient_team_id, %Puzzlet{} = puzzlet, pole, has_next) do
    persist_and_deliver(
      "puzzlet_withdrawn",
      recipient_team_id,
      nil,
      PlayerStrings.puzzlet_withdrawn_body(),
      %{
        "pole_id" => pole && pole.id,
        "pole_label" => pole && pole_name(pole),
        "puzzlet_id" => puzzlet.id,
        "has_next" => !!has_next
      },
      PlayerStrings.push_title("puzzlet_withdrawn")
    )
  end

  @doc """
  Register (or move) a push token. Upserts on the token so a device
  that changes users — new login on the same install — follows the
  new user instead of pushing to the old one.
  """
  def register_device_token(user_id, token, platform) do
    %DeviceToken{}
    |> DeviceToken.changeset(%{user_id: user_id, token: token, platform: platform})
    |> Repo.insert(
      on_conflict: {:replace, [:user_id, :platform, :updated_at]},
      conflict_target: :token
    )
  end

  @attack_cooldown_minutes 5

  defp maybe_signal_attack(_pole, nil, _team_id), do: :ok
  defp maybe_signal_attack(_pole, _owner_id, nil), do: :ok
  defp maybe_signal_attack(_pole, owner_id, team_id) when owner_id == team_id, do: :ok

  defp maybe_signal_attack(%Pole{} = pole, owner_id, attacker_id) do
    # The signal is a side effect of scanning — a bug here must never
    # 500 the scanning player mid-game. Log and carry on instead.
    if recent_attack_signal?(owner_id, attacker_id, pole.id) do
      :ok
    else
      write_attack_signal(pole, owner_id, attacker_id)
    end
  rescue
    error ->
      require Logger

      Logger.error("attack signal failed: #{Exception.message(error)}")
      :ok
  end

  defp recent_attack_signal?(recipient_id, sender_id, pole_id) do
    threshold = DateTime.add(DateTime.utc_now(), -@attack_cooldown_minutes * 60, :second)

    Notification
    |> where([n], n.recipient_team_id == ^recipient_id)
    |> where([n], n.sender_team_id == ^sender_id)
    |> where([n], n.type == "attack")
    # Text comparison, deliberately no ::uuid cast: a cast makes
    # Postgres type the parameter as uuid, and Postgrex then expects
    # the 16-byte dumped form — which raw fragments don't get from
    # Ecto automatically. Both sides are canonical lowercase UUID
    # strings (metadata was written from the same Elixir value), so
    # text equality is exact.
    |> where([n], fragment("?->>'pole_id' = ?", n.metadata, ^pole_id))
    |> where([n], n.inserted_at >= ^threshold)
    |> Repo.exists?()
  end

  defp write_attack_signal(%Pole{} = pole, recipient_id, sender_id) do
    attacker_name = team_name(sender_id)

    body = PlayerStrings.attack_body(attacker_name, pole_name(pole))

    deliver_team_notification("attack", pole, recipient_id, sender_id, body, attacker_name)
  end

  # Tell the previous owner they lost the pole. Same rescue rationale
  # as attack signals: a notification bug must never fail the capture.
  defp maybe_signal_pole_lost(_pole, nil, _capturing_team_id), do: :ok

  defp maybe_signal_pole_lost(_pole, owner_id, capturing_team_id) when owner_id == capturing_team_id, do: :ok

  defp maybe_signal_pole_lost(%Pole{} = pole, previous_owner_id, capturing_team_id) do
    captor_name = team_name(capturing_team_id)

    body = PlayerStrings.pole_lost_body(captor_name, pole_name(pole))

    deliver_team_notification(
      "pole_lost",
      pole,
      previous_owner_id,
      capturing_team_id,
      body,
      captor_name
    )
  rescue
    error ->
      require Logger

      Logger.error("pole-lost signal failed: #{Exception.message(error)}")
      :ok
  end

  defp team_name(team_id) do
    team = Repo.get(RegistrationsWeb.Team, team_id)
    team && team.name
  end

  # Persist + broadcast + push a team-directed notification. The
  # persisted row feeds the future notification-history / chat feed;
  # the broadcast gives currently-foregrounded apps a live toast; the
  # push reaches backgrounded/locked phones.
  defp deliver_team_notification(type, %Pole{} = pole, recipient_id, sender_id, body, sender_name) do
    persist_and_deliver(
      type,
      recipient_id,
      sender_id,
      body,
      %{
        "pole_id" => pole.id,
        "pole_label" => pole_name(pole),
        "sender_team_name" => sender_name
      },
      PlayerStrings.push_title(type, pole_name(pole))
    )
  end

  # The shared persist → socket broadcast → push funnel every
  # notification type goes through, whatever its origin (gameplay
  # side effects, organiser broadcasts, future chat).
  defp persist_and_deliver(type, recipient_id, sender_id, body, metadata, push_title) do
    result =
      %Notification{}
      |> Notification.changeset(%{
        type: type,
        recipient_team_id: recipient_id,
        sender_team_id: sender_id,
        body: body,
        metadata: metadata
      })
      |> Repo.insert()

    with {:ok, notification} <- result do
      RegistrationsWeb.Endpoint.broadcast("landgrab:map", "notification_created", %{
        id: notification.id,
        type: notification.type,
        recipient_team_id: notification.recipient_team_id,
        sender_team_id: notification.sender_team_id,
        body: notification.body,
        metadata: notification.metadata,
        inserted_at: notification.inserted_at
      })

      Registrations.Landgrab.Push.push_to_team(
        recipient_id,
        push_title,
        body,
        metadata |> Map.take(["pole_id"]) |> Map.put("type", type)
      )
    end

    :ok
  end

  @doc """
  A stake's name: always the stable generated handle from its id (`PoleNames`).
  The author-given `label` is no longer used as a name anywhere — every surface
  shows this synthetic name. Never the barcode — that's the scannable code, and
  putting it on a player-facing surface (a notification persists!) would let
  someone claim a stake without being there.
  """
  def pole_name(%Pole{} = pole), do: PoleNames.generate(pole.id, pole_number(pole))

  # A stake's unique, stable 3-digit number for its generated name.
  #
  # Deterministic but deliberately NOT tied to creation order — stakes are
  # often created in nearby batches, and a creation ordinal would let those
  # numbers reveal which stakes were made together. Instead we rank stakes by
  # `md5(id)` (a stable pseudo-random order uncorrelated with time), then map
  # that rank through a multiply coprime to 900 (a bijection) into 100–999.
  # The result: every stake gets a distinct number, scattered across the
  # range, that hints at neither creation order nor the total count.
  defp pole_number(%Pole{id: id}), do: Map.fetch!(pole_number_map(), id)

  # The ranking is identical for every stake in a given pole set, so we build
  # the whole id→number map in one query and memoise it for the process. A
  # single request handles the entire pole list in one process, so this turns
  # the pole list from one COUNT per stake into a single query per request —
  # and the pole set is fixed during the event, so it never churns.
  defp pole_number_map do
    case Process.get(:landgrab_pole_numbers) do
      nil ->
        map =
          from(p in Pole,
            order_by: [asc: fragment("md5(?::text)", p.id), asc: p.id],
            select: p.id
          )
          |> Repo.all()
          |> Enum.with_index()
          |> Map.new(fn {pole_id, rank} -> {pole_id, rem(rank * 137, 900) + 100} end)

        Process.put(:landgrab_pole_numbers, map)
        map

      map ->
        map
    end
  end

  defp insert_capture(pole_id, puzzlet_id, team_id) do
    # Normal-mode "one capture per puzzlet globally" is enforced here, not by a
    # DB constraint (the constraint relaxed to per-team so the relief valve can
    # let many teams solve one puzzlet). In relief mode this global guard is
    # SKIPPED — a puzzlet another team solved is fair game — leaving the
    # per-team unique below as the only limit (a team still can't double-solve).
    # There's a tiny race in normal mode — two teams answering the SAME puzzlet
    # correctly within the same instant could both pass this check — that the
    # old atomic unique prevented; at event scale it's negligible.
    if not relief_active?() and puzzlet_captured?(puzzlet_id) do
      {:error, :already_captured}
    else
      %OwnershipEvent{}
      |> OwnershipEvent.changeset(%{
        kind: "capture",
        pole_id: pole_id,
        puzzlet_id: puzzlet_id,
        team_id: team_id
      })
      |> Repo.insert()
      |> case do
        {:ok, capture} ->
          {:ok, capture}

        {:error, %Ecto.Changeset{errors: errors}} ->
          if Keyword.has_key?(errors, :puzzlet_id),
            do: {:error, :already_captured},
            else: {:error, :insert_failed}
      end
    end
  end

  # Whether any team already holds a capture on this puzzlet (the global
  # consume-once check for normal mode).
  defp puzzlet_captured?(puzzlet_id) do
    Repo.exists?(
      from(c in OwnershipEvent, where: c.puzzlet_id == ^puzzlet_id and c.kind == "capture")
    )
  end

  defp answers_match?(_type, expected, given) when not (is_binary(expected) and is_binary(given)), do: false

  defp answers_match?(:loose_text, expected, given) do
    normalize_loose(expected) == normalize_loose(given)
  end

  defp answers_match?(type, expected, given) when type in [:strict_text, :nfc] do
    expected == given
  end

  defp answers_match?(:barcode, expected, given) do
    expected == given or barcodes_equivalent?(expected, given)
  end

  defp answers_match?(_, _, _), do: false

  defp normalize_loose(s), do: s |> String.trim() |> String.downcase()

  # UPC-A (12 digits) and EAN-13 (13 digits) encode the same code differing
  # only by a leading zero, and scanners disagree on which they report: iOS
  # (AVFoundation) surfaces a UPC-A barcode as EAN-13 with a leading "0",
  # while Android (ML Kit) returns bare UPC-A without it. So the same physical
  # barcode won't string-equal across platforms. Treat two all-digit codes as
  # equal when they match once zero-padded to a common width — this also
  # covers any plain numeric code whose leading zero a scanner dropped.
  defp barcodes_equivalent?(expected, given) do
    numeric?(expected) and numeric?(given) and zero_padded_equal?(expected, given)
  end

  defp zero_padded_equal?(a, b) do
    width = max(String.length(a), String.length(b))
    String.pad_leading(a, width, "0") == String.pad_leading(b, width, "0")
  end

  defp numeric?(s), do: s != "" and String.match?(s, ~r/^[0-9]+$/)
end
