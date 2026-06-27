defmodule Registrations.Landgrab.Scope do
  @moduledoc """
  A query scope for the gameplay tables (`attempts`, `captures`) plus
  optional visibility restriction.

  * `Scope.real()` — the live event. Filters `test_session_id IS NULL`.
  * `Scope.test(session_id)` — a single test-play session. Filters
    `test_session_id = session_id`.
  * `Scope.test(session_id, visibility_user_id: id)` — additionally
    restricts pole/puzzlet visibility to content the user created or is
    assigned to validate. Used for validators in test play. Omit for
    supervisors/admins who see everything.

  Every gameplay query function in `Registrations.Landgrab` takes a scope.
  Default is `Scope.real()` so existing call sites are unaffected.
  """

  import Ecto.Query

  defstruct [:test_session_id, :visibility_user_id]

  @type t :: %__MODULE__{
          test_session_id: binary() | nil,
          visibility_user_id: binary() | nil
        }

  @spec real() :: t()
  def real, do: %__MODULE__{test_session_id: nil, visibility_user_id: nil}

  @spec test(binary(), keyword()) :: t()
  def test(session_id, opts \\ []) when is_binary(session_id) do
    %__MODULE__{
      test_session_id: session_id,
      visibility_user_id: Keyword.get(opts, :visibility_user_id)
    }
  end

  @doc "Returns true when the scope refers to a test session."
  def test?(%__MODULE__{test_session_id: id}), do: not is_nil(id)

  @doc "Returns true when the scope restricts visibility to a specific user."
  def restricted?(%__MODULE__{visibility_user_id: id}), do: not is_nil(id)

  @doc """
  Filter an Ecto query to rows that belong to this scope. The bound table
  must have a `test_session_id` column.
  """
  def apply(query, %__MODULE__{test_session_id: nil}) do
    from(q in query, where: is_nil(q.test_session_id))
  end

  def apply(query, %__MODULE__{test_session_id: id}) do
    from(q in query, where: q.test_session_id == ^id)
  end

  @doc """
  The `test_session_id` value to write when persisting a row, or nil for
  real-game writes.
  """
  def write_id(%__MODULE__{test_session_id: id}), do: id
end
