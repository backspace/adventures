defmodule Registrations.Poles do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Registrations.Poles.Attempt
  alias Registrations.Poles.Capture
  alias Registrations.Poles.Pole
  alias Registrations.Poles.Puzzlet
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

            cond do
              active && team_locked_out?(active, team_id) ->
                {:error, :team_locked_out, pole}

              true ->
                {attempts_remaining, prior_wrong} =
                  case active do
                    nil ->
                      {nil, []}

                    puzzlet ->
                      {max(@max_attempts_per_puzzlet - team_wrong_attempts(puzzlet, team_id), 0),
                       team_wrong_answers(puzzlet, team_id)}
                  end

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

  def list_drafts_for_user(%{id: user_id}) do
    poles =
      Pole
      |> where([p], p.creator_id == ^user_id)
      |> order_by([p], desc: p.inserted_at)
      |> Repo.all()

    puzzlets =
      Puzzlet
      |> where([p], p.creator_id == ^user_id)
      |> order_by([p], desc: p.inserted_at)
      |> Repo.all()

    %{poles: poles, puzzlets: puzzlets}
  end

  def list_puzzlets do
    Repo.all(Puzzlet)
  end

  def list_unassigned_puzzlets do
    Repo.all(from(p in Puzzlet, where: is_nil(p.pole_id)))
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
  def active_puzzlet_for_pole(pole, user_id \\ nil)

  def active_puzzlet_for_pole(%Pole{id: pole_id}, user_id) do
    captured_puzzlet_ids = from(c in Capture, select: c.puzzlet_id)

    query =
      Puzzlet
      |> where([p], p.pole_id == ^pole_id)
      |> where([p], p.status == :validated)
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
    from(c in Capture,
      join: p in Puzzlet,
      on: p.id == c.puzzlet_id,
      where: p.pole_id == ^pole_id,
      order_by: [desc: c.inserted_at],
      limit: 1,
      select: c.team_id
    )
    |> Repo.one()
  end

  def pole_locked?(%Pole{id: pole_id}) do
    validated_count =
      from(p in Puzzlet,
        where: p.pole_id == ^pole_id and p.status == :validated,
        select: count(p.id)
      )
      |> Repo.one()

    captured_count =
      from(c in Capture,
        join: p in Puzzlet,
        on: p.id == c.puzzlet_id,
        where: p.pole_id == ^pole_id and p.status == :validated,
        select: count(c.id)
      )
      |> Repo.one()

    validated_count > 0 and validated_count == captured_count
  end

  @doc """
  How many times this team has answered this puzzlet incorrectly.
  Returns 0 when team_id is nil (a user not yet on a team has no attempts).
  """
  def team_wrong_attempts(_puzzlet, nil), do: 0

  def team_wrong_attempts(%Puzzlet{id: puzzlet_id}, team_id) do
    from(a in Attempt,
      where: a.puzzlet_id == ^puzzlet_id and a.team_id == ^team_id and a.correct == false,
      select: count(a.id)
    )
    |> Repo.one()
  end

  def team_locked_out?(_puzzlet, nil), do: false

  def team_locked_out?(%Puzzlet{} = puzzlet, team_id) do
    team_wrong_attempts(puzzlet, team_id) >= @max_attempts_per_puzzlet
  end

  @doc """
  Distinct wrong answers this team has submitted for this puzzlet, in
  chronological order of first occurrence.
  """
  def team_wrong_answers(_puzzlet, nil), do: []

  def team_wrong_answers(%Puzzlet{id: puzzlet_id}, team_id) do
    from(a in Attempt,
      where: a.puzzlet_id == ^puzzlet_id and a.team_id == ^team_id and a.correct == false,
      order_by: [asc: a.inserted_at],
      select: a.answer_given
    )
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
        correct? = answers_match?(puzzlet.answer, answer_given)

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
              remaining = @max_attempts_per_puzzlet - team_wrong_attempts(puzzlet, team_id)
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
    RegistrationsWeb.Endpoint.broadcast("poles:map", "pole_updated", %{
      id: pole.id,
      current_owner_team_id: capture.team_id,
      locked: pole_locked?(pole),
      captured_by_team_id: capture.team_id,
      captured_at: capture.inserted_at
    })
  end

  defp insert_capture(puzzlet_id, team_id) do
    %Capture{}
    |> Capture.changeset(%{puzzlet_id: puzzlet_id, team_id: team_id})
    |> Repo.insert()
    |> case do
      {:ok, capture} -> {:ok, capture}
      {:error, %Ecto.Changeset{errors: errors}} ->
        if Keyword.has_key?(errors, :puzzlet_id), do: {:error, :already_captured}, else: {:error, :insert_failed}
    end
  end

  defp answers_match?(expected, given) when is_binary(expected) and is_binary(given) do
    normalize(expected) == normalize(given)
  end

  defp answers_match?(_, _), do: false

  defp normalize(s), do: s |> String.trim() |> String.downcase()
end
