defmodule Registrations.Landgrab do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Registrations.Landgrab.Attachment
  alias Registrations.Landgrab.Attempt
  alias Registrations.Landgrab.Capture
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.Thumbnail
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
  def list_poles_with_state do
    Pole
    |> Repo.all()
    |> Enum.map(&pole_with_state/1)
  end

  def pole_with_state(%Pole{} = pole) do
    %{
      pole: pole,
      current_owner_team_id: current_owner_team_id_for_pole(pole),
      locked?: pole_locked?(pole)
    }
  end

  @doc """
  Returns the full payload for a barcode scan by a particular team:
  pole state plus active puzzlet (or nil if locked) and the team's
  remaining attempts on that puzzlet.
  """
  def scan_payload(barcode, team_id, user_id \\ nil) do
    case get_pole_by_barcode(barcode) do
      nil ->
        {:error, :not_found}

      pole ->
        cond do
          user_id && pole.creator_id == user_id ->
            {:error, :own_creation, pole}

          pole_locked?(pole) ->
            state = pole_with_state(pole)

            {:ok,
             Map.merge(state, %{
               active_puzzlet: nil,
               attempts_remaining: nil,
               previous_wrong_answers: []
             })}

          pole_owned_by_team?(pole, team_id) ->
            {:error, :already_owner, pole}

          true ->
            state = pole_with_state(pole)
            active = active_puzzlet_for_pole(pole, user_id)

            if active && team_locked_out?(active, team_id) do
              {:error, :team_locked_out, pole}
            else
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
  def active_puzzlet_for_pole(%Pole{id: pole_id}, user_id \\ nil) do
    captured_puzzlet_ids = select(Capture, [c], c.puzzlet_id)

    query =
      Puzzlet
      |> where([p], p.pole_id == ^pole_id)
      |> where([p], p.status == :validated)
      |> where([p], not p.validator_only)
      |> where([p], p.id not in subquery(captured_puzzlet_ids))
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

  def pole_owned_by_team?(_pole, nil), do: false

  def pole_owned_by_team?(%Pole{} = pole, team_id) do
    current_owner_team_id_for_pole(pole) == team_id
  end

  def current_owner_team_id_for_pole(%Pole{id: pole_id}) do
    Capture
    |> join(:inner, [c], p in Puzzlet, on: p.id == c.puzzlet_id)
    |> where([_c, p], p.pole_id == ^pole_id)
    |> order_by([c, _p], desc: c.inserted_at)
    |> limit(1)
    |> select([c, _p], c.team_id)
    |> Repo.one()
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

    captured_count =
      Capture
      |> join(:inner, [c], p in Puzzlet, on: p.id == c.puzzlet_id)
      |> where(
        [_c, p],
        p.pole_id == ^pole_id and p.status == :validated and not p.validator_only
      )
      |> select([c, _p], count(c.id))
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
      puzzlet.creator_id == user_id ->
        {:error, :own_creation}

      pole && pole.creator_id == user_id ->
        {:error, :own_creation}

      pole && pole_owned_by_team?(pole, team_id) ->
        {:error, :already_owner}

      team_locked_out?(puzzlet, team_id) ->
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
                correct: correct?
              })
              |> Repo.insert!()

            if correct? do
              case insert_capture(puzzlet.id, team_id) do
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

  # Attack signals fire only when the pole is owned by someone other
  # than the scanning team, and only when a fresh signal hasn't been
  # written for the same (defender, attacker, pole) trio in the last
  # @attack_cooldown. The cooldown keeps the `notifications` history
  # from filling up with duplicate rows when an attacker retries a
  # puzzlet many times.
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

  defp insert_capture(puzzlet_id, team_id) do
    %Capture{}
    |> Capture.changeset(%{
      puzzlet_id: puzzlet_id,
      team_id: team_id
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
end
