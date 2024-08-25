defmodule Registrations.Waydowntown.Answer do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Registrations.Repo
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Game

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"

  schema "answers" do
    field(:answer, :string)
    field(:correct, :boolean, default: false)

    belongs_to(:game, Game, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [:answer, :correct, :game_id])
    |> validate_required([:answer, :correct, :game_id])
    |> assoc_constraint(:game)
    |> validate_game_has_no_winner()
    |> validate_answer_overwrite()
  end

  defp validate_answer_overwrite(changeset) do
    with game_id when not is_nil(game_id) <- get_field(changeset, :game_id),
         %{incarnation: %{placed: false}} = game <- Game |> Repo.get(game_id) |> Repo.preload(:incarnation),
         %Answer{} = existing_answer <- Repo.get_by(Answer, game_id: game_id) do
      change(changeset, %{id: existing_answer.id})
    else
      _ -> changeset
    end
  end

  defp validate_game_has_no_winner(changeset) do
    changeset
    |> get_field(:game_id)
    |> case do
      nil ->
        changeset

      game_id ->
        Game
        |> Registrations.Repo.get(game_id)
        |> case do
          %Game{winner_answer_id: nil} -> changeset
          %Game{} -> add_error(changeset, :game_id, "game already has a winner")
          nil -> changeset
        end
    end
  end
end
