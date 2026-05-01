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
  def scan_payload(barcode, team_id) do
    case get_pole_by_barcode(barcode) do
      nil ->
        {:error, :not_found}

      pole ->
        cond do
          pole_locked?(pole) ->
            state = pole_with_state(pole)
            {:ok, Map.merge(state, %{active_puzzlet: nil, attempts_remaining: nil})}

          pole_owned_by_team?(pole, team_id) ->
            {:error, :already_owner, pole}

          true ->
            state = pole_with_state(pole)
            active = active_puzzlet_for_pole(pole)

            attempts_remaining =
              case active do
                nil ->
                  nil

                puzzlet ->
                  max(@max_attempts_per_puzzlet - team_wrong_attempts(puzzlet, team_id), 0)
              end

            {:ok, Map.merge(state, %{active_puzzlet: active, attempts_remaining: attempts_remaining})}
        end
    end
  end

  def create_pole(attrs) do
    %Pole{}
    |> Pole.changeset(attrs)
    |> Repo.insert()
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

  @doc """
  Returns the easiest validated puzzlet for the pole that has not yet been
  captured. Returns nil when the pole is locked (all puzzlets captured) or has
  no validated puzzlets assigned.
  """
  def active_puzzlet_for_pole(%Pole{id: pole_id}) do
    captured_puzzlet_ids = from(c in Capture, select: c.puzzlet_id)

    Puzzlet
    |> where([p], p.pole_id == ^pole_id)
    |> where([p], p.status == :validated)
    |> where([p], p.id not in subquery(captured_puzzlet_ids))
    |> order_by([p], asc: p.difficulty, asc: p.inserted_at)
    |> limit(1)
    |> Repo.one()
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

      team_locked_out?(puzzlet, team_id) ->
        {:error, :locked_out}

      true ->
        correct? = answers_match?(puzzlet.answer, answer_given)

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
    end
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
