defmodule Registrations.Landgrab do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Registrations.Landgrab.Attachment
  alias Registrations.Landgrab.Attempt
  alias Registrations.Landgrab.Capture
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.Scope
  alias Registrations.Landgrab.TestSession
  alias Registrations.Landgrab.Thumbnail
  alias Registrations.Landgrab.Validations.PoleValidation
  alias Registrations.Landgrab.Validations.PuzzletValidation
  alias Registrations.Repo

  @max_attempts_per_puzzlet 3

  def max_attempts_per_puzzlet, do: @max_attempts_per_puzzlet

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
  def list_poles_with_state(scope \\ Scope.real()) do
    Pole
    |> filter_visible_poles(scope)
    |> Repo.all()
    |> Enum.map(&pole_with_state(&1, scope))
  end

  # If the scope restricts visibility (a validator in test play), filter
  # the pole query to poles the user (a) created, (b) is assigned to
  # validate, or (c) is validating any puzzlet on. Unrestricted scopes pass
  # the query through unchanged.
  defp filter_visible_poles(query, %Scope{visibility_user_id: nil}), do: query

  defp filter_visible_poles(query, %Scope{visibility_user_id: user_id}) do
    pole_validation_ids =
      from(pv in PoleValidation, where: pv.validator_id == ^user_id, select: pv.pole_id)

    puzzlet_validation_pole_ids =
      from(puv in PuzzletValidation,
        join: pz in Puzzlet,
        on: pz.id == puv.puzzlet_id,
        where: puv.validator_id == ^user_id,
        select: pz.pole_id
      )

    from(p in query,
      where:
        p.creator_id == ^user_id or
          p.id in subquery(pole_validation_ids) or
          p.id in subquery(puzzlet_validation_pole_ids)
    )
  end

  # Whether a specific pole is visible to a user under the scope. Used by
  # scan_payload to translate invisibility into :not_found.
  defp pole_visible?(_pole, %Scope{visibility_user_id: nil}), do: true

  defp pole_visible?(%Pole{id: pole_id}, %Scope{visibility_user_id: user_id}) do
    Pole
    |> where([p], p.id == ^pole_id)
    |> filter_visible_poles(%Scope{visibility_user_id: user_id})
    |> Repo.exists?()
  end

  def pole_with_state(%Pole{} = pole, scope \\ Scope.real()) do
    %{
      pole: pole,
      current_owner_team_id: current_owner_team_id_for_pole(pole, scope),
      locked?: pole_locked?(pole, scope)
    }
  end

  @doc """
  Returns the full payload for a barcode scan by a particular team:
  pole state plus active puzzlet (or nil if locked) and the team's
  remaining attempts on that puzzlet.

  In test scope, the "own creation" check is skipped so authors and
  validators can rehearse against their own content.
  """
  def scan_payload(barcode, team_id, user_id \\ nil, scope \\ Scope.real()) do
    case get_pole_by_barcode(barcode) do
      nil ->
        {:error, :not_found}

      pole ->
        cond do
          # Invisible poles look like "not found" — don't leak existence.
          not pole_visible?(pole, scope) ->
            {:error, :not_found}

          not Scope.test?(scope) && user_id && pole.creator_id == user_id ->
            {:error, :own_creation, pole}

          pole_locked?(pole, scope) ->
            state = pole_with_state(pole, scope)

            {:ok,
             Map.merge(state, %{
               active_puzzlet: nil,
               attempts_remaining: nil,
               previous_wrong_answers: []
             })}

          pole_owned_by_team?(pole, team_id, scope) ->
            {:error, :already_owner, pole}

          true ->
            state = pole_with_state(pole, scope)
            active = active_puzzlet_for_pole(pole, user_id, scope)

            if active && team_locked_out?(active, team_id, scope) do
              {:error, :team_locked_out, pole}
            else
              {attempts_remaining, prior_wrong} =
                case active do
                  nil ->
                    {nil, []}

                  puzzlet ->
                    {max(
                       @max_attempts_per_puzzlet -
                         team_wrong_attempts(puzzlet, team_id, scope),
                       0
                     ), team_wrong_answers(puzzlet, team_id, scope)}
                end

              maybe_signal_attack(pole, state.current_owner_team_id, team_id, scope)

              {:ok,
               Map.merge(state, %{
                 active_puzzlet: active,
                 attempts_remaining: attempts_remaining,
                 previous_wrong_answers: prior_wrong
               })}
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
  def active_puzzlet_for_pole(pole, user_id \\ nil, scope \\ Scope.real())

  def active_puzzlet_for_pole(%Pole{} = pole, user_id, scope) do
    if Scope.test?(scope) do
      test_active_puzzlet(pole, scope)
    else
      real_active_puzzlet(pole, user_id, scope)
    end
  end

  defp real_active_puzzlet(%Pole{id: pole_id}, user_id, scope) do
    captured_puzzlet_ids =
      Capture
      |> Scope.apply(scope)
      |> select([c], c.puzzlet_id)

    query =
      Puzzlet
      |> where([p], p.pole_id == ^pole_id)
      |> where([p], p.status == :validated)
      |> where([p], p.id not in subquery(captured_puzzlet_ids))
      |> filter_visible_puzzlets(scope)
      |> order_by([p], asc: p.difficulty, asc: p.inserted_at)
      |> limit(1)

    query =
      if user_id do
        where(query, [p], is_nil(p.creator_id) or p.creator_id != ^user_id)
      else
        query
      end

    Repo.one(query)
  end

  # In a test session, puzzlets are typically not yet wired to specific
  # poles. Pick from the five geographically-nearest not-yet-retired
  # puzzlets (with a location), not yet captured in this session, and
  # randomize so successive demos visit different ones.
  #
  # Unlike the real game (which requires `:validated`), test play also
  # includes `:draft` and `:in_review` — authors need to be able to
  # rehearse a puzzlet before validation without a separate flag. The
  # visibility filter (see `filter_visible_puzzlets/2`) still gates
  # who sees whose drafts.
  defp test_active_puzzlet(%Pole{latitude: lat, longitude: lon}, scope) do
    captured_puzzlet_ids =
      Capture
      |> Scope.apply(scope)
      |> select([c], c.puzzlet_id)

    candidates =
      Puzzlet
      |> where([p], p.status in [:draft, :in_review, :validated])
      |> where([p], p.id not in subquery(captured_puzzlet_ids))
      |> where([p], not is_nil(p.latitude) and not is_nil(p.longitude))
      |> filter_visible_puzzlets(scope)
      |> order_by(
        [p],
        fragment(
          "((? - ?) * (? - ?) + (? - ?) * (? - ?))",
          p.latitude,
          ^lat,
          p.latitude,
          ^lat,
          p.longitude,
          ^lon,
          p.longitude,
          ^lon
        )
      )
      |> limit(5)
      |> Repo.all()

    case candidates do
      [] -> nil
      list -> Enum.random(list)
    end
  end

  defp filter_visible_puzzlets(query, %Scope{visibility_user_id: nil}), do: query

  defp filter_visible_puzzlets(query, %Scope{visibility_user_id: user_id}) do
    assigned_puzzlet_ids =
      from(puv in PuzzletValidation,
        where: puv.validator_id == ^user_id,
        select: puv.puzzlet_id
      )

    # Pole-level validators can see all puzzlets on the poles they're
    # assigned to — otherwise they couldn't rehearse the pole's gameplay.
    assigned_pole_ids =
      from(pv in PoleValidation,
        where: pv.validator_id == ^user_id,
        select: pv.pole_id
      )

    from(p in query,
      where:
        p.creator_id == ^user_id or
          p.id in subquery(assigned_puzzlet_ids) or
          p.pole_id in subquery(assigned_pole_ids)
    )
  end

  def pole_owned_by_team?(_pole, nil, _scope), do: false
  def pole_owned_by_team?(pole, team_id), do: pole_owned_by_team?(pole, team_id, Scope.real())

  def pole_owned_by_team?(%Pole{} = pole, team_id, %Scope{} = scope) do
    # In test scope, "ownership" means "captured during this session" —
    # team identity doesn't matter, just session membership.
    case scope do
      %Scope{test_session_id: nil} ->
        current_owner_team_id_for_pole(pole, scope) == team_id

      _ ->
        not is_nil(current_owner_team_id_for_pole(pole, scope)) or
          pole_captured_in_scope?(pole, scope)
    end
  end

  defp pole_captured_in_scope?(%Pole{id: pole_id}, scope) do
    Capture
    |> Scope.apply(scope)
    |> join(:inner, [c], p in Puzzlet, on: p.id == c.puzzlet_id)
    |> where([c, p], c.pole_id == ^pole_id or p.pole_id == ^pole_id)
    |> Repo.exists?()
  end

  def current_owner_team_id_for_pole(pole), do: current_owner_team_id_for_pole(pole, Scope.real())

  def current_owner_team_id_for_pole(%Pole{id: pole_id}, %Scope{} = scope) do
    Capture
    |> Scope.apply(scope)
    |> join(:inner, [c], p in Puzzlet, on: p.id == c.puzzlet_id)
    # Match either a directly-recorded pole_id on the capture (test-
    # play, where the puzzlet is often unattached) or the puzzlet's
    # own pole_id (real gameplay). Covers both worlds without needing
    # to backfill captures.pole_id for existing rows.
    |> where([c, p], c.pole_id == ^pole_id or p.pole_id == ^pole_id)
    |> order_by([c, _p], desc: c.inserted_at)
    |> limit(1)
    |> select_owner_id(scope)
    |> Repo.one()
  end

  # In real scope, captures.team_id is the owner. In test scope,
  # team_id is nil (there's no team in test-play, and the FK would
  # reject a user id), so surface the test_session_id — non-null,
  # stable per session, and enough for the map to render "captured".
  defp select_owner_id(query, %Scope{test_session_id: nil}) do
    select(query, [c, _p], c.team_id)
  end

  defp select_owner_id(query, %Scope{}) do
    select(query, [c, _p], c.test_session_id)
  end

  def pole_locked?(pole), do: pole_locked?(pole, Scope.real())

  def pole_locked?(%Pole{id: pole_id}, %Scope{} = scope) do
    validated_count =
      Repo.one(from(p in Puzzlet, where: p.pole_id == ^pole_id and p.status == :validated, select: count(p.id)))

    captured_count =
      Capture
      |> Scope.apply(scope)
      |> join(:inner, [c], p in Puzzlet, on: p.id == c.puzzlet_id)
      |> where([_c, p], p.pole_id == ^pole_id and p.status == :validated)
      |> select([c, _p], count(c.id))
      |> Repo.one()

    validated_count > 0 and validated_count == captured_count
  end

  @doc """
  How many times this team (or test session) has answered this puzzlet
  incorrectly. Returns 0 when there's no scope subject (no team in real
  scope, no session in test scope).
  """
  def team_wrong_attempts(puzzlet, team_id), do: team_wrong_attempts(puzzlet, team_id, Scope.real())

  def team_wrong_attempts(_puzzlet, nil, %Scope{test_session_id: nil}), do: 0

  def team_wrong_attempts(%Puzzlet{id: puzzlet_id}, team_id, %Scope{} = scope) do
    Attempt
    |> Scope.apply(scope)
    |> where([a], a.puzzlet_id == ^puzzlet_id and a.correct == false)
    |> maybe_filter_team(team_id, scope)
    |> select([a], count(a.id))
    |> Repo.one()
  end

  def team_locked_out?(puzzlet, team_id), do: team_locked_out?(puzzlet, team_id, Scope.real())

  def team_locked_out?(_puzzlet, nil, %Scope{test_session_id: nil}), do: false

  def team_locked_out?(%Puzzlet{} = puzzlet, team_id, %Scope{} = scope) do
    team_wrong_attempts(puzzlet, team_id, scope) >= @max_attempts_per_puzzlet
  end

  @doc """
  Distinct wrong answers this team (or test session) has submitted for
  this puzzlet, in chronological order of first occurrence.
  """
  def team_wrong_answers(puzzlet, team_id), do: team_wrong_answers(puzzlet, team_id, Scope.real())

  def team_wrong_answers(_puzzlet, nil, %Scope{test_session_id: nil}), do: []

  def team_wrong_answers(%Puzzlet{id: puzzlet_id}, team_id, %Scope{} = scope) do
    Attempt
    |> Scope.apply(scope)
    |> where([a], a.puzzlet_id == ^puzzlet_id and a.correct == false)
    |> maybe_filter_team(team_id, scope)
    |> order_by([a], asc: a.inserted_at)
    |> select([a], a.answer_given)
    |> Repo.all()
    |> Enum.uniq()
  end

  # Real-game queries filter by team_id; test-scope queries are already
  # narrowed by test_session_id and ignore team_id (no team concept in
  # solo test play).
  defp maybe_filter_team(query, _team_id, %Scope{test_session_id: id}) when not is_nil(id), do: query

  defp maybe_filter_team(query, team_id, _scope) when not is_nil(team_id), do: where(query, [a], a.team_id == ^team_id)

  defp maybe_filter_team(query, _team_id, _scope), do: query

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
  def record_attempt(puzzlet, team_id, user_id, answer_given),
    do: record_attempt(puzzlet, team_id, user_id, answer_given, Scope.real(), nil)

  def record_attempt(puzzlet, team_id, user_id, answer_given, scope),
    do: record_attempt(puzzlet, team_id, user_id, answer_given, scope, nil)

  # `scanned_pole_id` records which pole the client was looking at
  # when they submitted. Only meaningful when the puzzlet isn't
  # attached to a pole (test-play with unattached puzzlets); real
  # captures pass nil and resolve the pole via `puzzlet.pole_id`.
  def record_attempt(%Puzzlet{} = puzzlet, team_id, user_id, answer_given, %Scope{} = scope, scanned_pole_id) do
    effective_pole_id = puzzlet.pole_id || scanned_pole_id
    pole = effective_pole_id && Repo.get(Pole, effective_pole_id)
    test_mode? = Scope.test?(scope)

    cond do
      # Own-creation block doesn't apply in test mode — testers walking
      # through their own content should be able to.
      not test_mode? && puzzlet.creator_id == user_id ->
        {:error, :own_creation}

      not test_mode? && pole && pole.creator_id == user_id ->
        {:error, :own_creation}

      pole && pole_owned_by_team?(pole, team_id, scope) ->
        {:error, :already_owner}

      team_locked_out?(puzzlet, team_id, scope) ->
        {:error, :locked_out}

      true ->
        correct? = answers_match?(puzzlet.answer_type, puzzlet.answer, answer_given)

        result =
          Repo.transaction(fn ->
            attempt =
              %Attempt{}
              |> Attempt.changeset(%{
                puzzlet_id: puzzlet.id,
                team_id: team_id,
                user_id: user_id,
                answer_given: answer_given,
                correct: correct?,
                test_session_id: Scope.write_id(scope)
              })
              |> Repo.insert!()

            if correct? do
              case insert_capture(puzzlet.id, team_id, scope, effective_pole_id) do
                {:ok, capture} ->
                  %{result: :captured, attempt: attempt, capture: capture}

                {:error, :already_captured} ->
                  Repo.rollback(:already_captured)
              end
            else
              remaining =
                @max_attempts_per_puzzlet - team_wrong_attempts(puzzlet, team_id, scope)

              %{result: :incorrect, attempt: attempt, attempts_remaining: max(remaining, 0)}
            end
          end)

        # Only broadcast pole updates for real captures — test-play captures
        # are private to the tester and shouldn't appear on the live map.
        with {:ok, %{result: :captured, capture: capture}} <- result,
             %Pole{} = captured_pole <- pole,
             false <- test_mode? do
          broadcast_pole_update(captured_pole, capture)
        end

        result
    end
  end

  defp broadcast_pole_update(%Pole{} = pole, %Capture{} = capture) do
    RegistrationsWeb.Endpoint.broadcast("landgrab:map", "pole_updated", %{
      id: pole.id,
      current_owner_team_id: capture.team_id,
      locked: pole_locked?(pole),
      captured_by_team_id: capture.team_id,
      captured_at: capture.inserted_at
    })
  end

  # Attack signals fire only in the real game (test-play captures /
  # scans are private to the tester), only when the pole is owned by
  # someone other than the scanning team, and only when a fresh
  # signal hasn't been written for the same (defender, attacker,
  # pole) trio in the last @attack_cooldown. The cooldown keeps the
  # `notifications` history from filling up with duplicate rows when
  # an attacker retries a puzzlet many times.
  @attack_cooldown_minutes 5

  defp maybe_signal_attack(_pole, _owner_id, _team_id, %Scope{test_session_id: id})
       when not is_nil(id),
       do: :ok

  defp maybe_signal_attack(_pole, nil, _team_id, _scope), do: :ok
  defp maybe_signal_attack(_pole, _owner_id, nil, _scope), do: :ok
  defp maybe_signal_attack(_pole, owner_id, team_id, _scope) when owner_id == team_id, do: :ok

  defp maybe_signal_attack(%Pole{} = pole, owner_id, attacker_id, _scope) do
    if recent_attack_signal?(owner_id, attacker_id, pole.id) do
      :ok
    else
      write_attack_signal(pole, owner_id, attacker_id)
    end
  end

  defp recent_attack_signal?(recipient_id, sender_id, pole_id) do
    threshold = DateTime.add(DateTime.utc_now(), -@attack_cooldown_minutes * 60, :second)

    Notification
    |> where([n], n.recipient_team_id == ^recipient_id)
    |> where([n], n.sender_team_id == ^sender_id)
    |> where([n], n.type == "attack")
    |> where([n], fragment("(?->>'pole_id')::uuid = ?", n.metadata, ^pole_id))
    |> where([n], n.inserted_at >= ^threshold)
    |> Repo.exists?()
  end

  defp write_attack_signal(%Pole{} = pole, recipient_id, sender_id) do
    attacker = Repo.get(RegistrationsWeb.Team, sender_id)
    attacker_name = attacker && attacker.name
    body =
      case attacker_name do
        nil -> "A rival team scanned #{display_name(pole)}"
        name -> "#{name} scanned #{display_name(pole)}"
      end

    result =
      %Notification{}
      |> Notification.changeset(%{
        type: "attack",
        recipient_team_id: recipient_id,
        sender_team_id: sender_id,
        body: body,
        metadata: %{
          "pole_id" => pole.id,
          "pole_label" => pole.label,
          "pole_barcode" => pole.barcode,
          "attacker_team_name" => attacker_name
        }
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
    end

    :ok
  end

  defp display_name(%Pole{label: label}) when is_binary(label) and label != "", do: label
  defp display_name(%Pole{barcode: barcode}), do: barcode

  defp insert_capture(puzzlet_id, team_id, scope, pole_id) do
    %Capture{}
    |> Capture.changeset(%{
      puzzlet_id: puzzlet_id,
      team_id: team_id,
      test_session_id: Scope.write_id(scope),
      pole_id: pole_id
    })
    |> Repo.insert()
    |> case do
      {:ok, capture} ->
        {:ok, capture}

      {:error, %Ecto.Changeset{errors: errors}} ->
        if Keyword.has_key?(errors, :puzzlet_id), do: {:error, :already_captured}, else: {:error, :insert_failed}
    end
  end

  defp answers_match?(_type, expected, given) when not (is_binary(expected) and is_binary(given)), do: false

  defp answers_match?(:loose_text, expected, given) do
    normalize_loose(expected) == normalize_loose(given)
  end

  defp answers_match?(type, expected, given) when type in [:strict_text, :barcode, :nfc] do
    expected == given
  end

  defp answers_match?(_, _, _), do: false

  defp normalize_loose(s), do: s |> String.trim() |> String.downcase()

  # ─── Test sessions ───────────────────────────────────────────────────

  def create_test_session(creator, attrs \\ %{}) do
    attrs = Map.put(attrs, :creator_id, creator.id)

    %TestSession{}
    |> TestSession.changeset(attrs)
    |> Repo.insert()
  end

  def get_test_session(id), do: Repo.get(TestSession, id)

  def get_test_session!(id), do: Repo.get!(TestSession, id)

  def list_test_sessions_for_user(%{id: user_id}) do
    TestSession
    |> where([s], s.creator_id == ^user_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def end_test_session(%TestSession{} = session) do
    session
    |> TestSession.changeset(%{ended_at: DateTime.truncate(DateTime.utc_now(), :second)})
    |> Repo.update()
  end
end
