defmodule Registrations.Waydowntown do
  @moduledoc """
  The Waydowntown context.
  """

  import Ecto.Query, warn: false
  alias Registrations.Repo

  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Game
  alias Registrations.Waydowntown.Incarnation

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Repo.all(Game) |> Repo.preload(incarnation: [region: [:parent]])
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id) do
    Repo.get!(Game, id)
    |> Repo.preload([:answers, incarnation: [region: [:parent]]])
  end

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs \\ %{}, incarnation_filter \\ nil) do
    incarnation = get_random_incarnation(incarnation_filter)

    %Game{}
    |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
    |> Repo.insert()
  end

  defp get_random_incarnation(nil), do: Repo.all(Incarnation) |> Enum.random()

  defp get_random_incarnation(concept) do
    Incarnation
    |> where([i], i.concept == ^concept)
    |> Repo.all()
    |> Enum.random()
  end

  @doc """
  Gets a single answer.

  Raises `Ecto.NoResultsError` if the Answer does not exist.

  ## Examples

      iex> get_answer!(123)
      %Answer{}

      iex> get_answer!(456)
      ** (Ecto.NoResultsError)

  """
  def get_answer!(id), do: Repo.get!(Answer, id)

  @doc """
  Creates an answer.

  ## Examples

      iex> create_answer(%{field: value})
      {:ok, %Answer{}}

      iex> create_answer(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_answer(%{"answer" => answer_text, "game_id" => game_id}) do
    game = get_game!(game_id)
    incarnation = game.incarnation

    %Answer{}
    |> Answer.changeset(%{
      "answer" => answer_text,
      "correct" => check_answer_correctness(incarnation, answer_text),
      "game_id" => game_id
    })
    |> Repo.insert()
    |> case do
      {:ok, answer} ->
        if answer.correct and single_answer_game?(incarnation) do
          update_game_winner(game, answer)
        end

        {:ok, Repo.preload(answer, game: [:answers, :incarnation])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_game_progress(game) do
    correct_answers = Enum.count(game.answers, & &1.correct)
    total_answers = length(game.incarnation.answers)

    %{
      correct_answers: correct_answers,
      total_answers: total_answers,
      complete: game.winner_answer_id != nil
    }
  end

  defp check_answer_correctness(
         %Incarnation{concept: "fill_in_the_blank", answer: correct_answer},
         answer_text
       ) do
    String.downcase(String.trim(correct_answer)) == String.downcase(String.trim(answer_text))
  end

  defp check_answer_correctness(
         %Incarnation{concept: "bluetooth_collector", answers: correct_answers},
         answer_text
       ) do
    answer_text in correct_answers
  end

  defp check_answer_correctness(
         %Incarnation{concept: "code_collector", answers: correct_answers},
         answer_text
       ) do
    answer_text in correct_answers
  end

  defp single_answer_game?(%Incarnation{concept: "fill_in_the_blank"}), do: true
  defp single_answer_game?(_), do: false

  defp update_game_winner(game, answer) do
    game
    |> Game.changeset(%{winner_answer_id: answer.id})
    |> Repo.update!()
  end
end
