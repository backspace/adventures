defmodule Registrations.Waydowntown do
  @moduledoc """
  The Waydowntown context.
  """

  import Ecto.Query, warn: false

  alias Registrations.Repo
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Game
  alias Registrations.Waydowntown.Incarnation

  @doc false
  defp concepts_yaml do
    YamlElixir.read_from_file!(Path.join(:code.priv_dir(:registrations), "concepts.yaml"))
  end

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Game |> Repo.all() |> Repo.preload(incarnation: [region: [:parent]])
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
    Game
    |> Repo.get!(id)
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
    case_result =
      case incarnation_filter do
        %{"placed" => "false"} ->
          create_game_with_new_incarnation(attrs)

        %{"placed" => "true"} ->
          create_game_with_placed_incarnation(attrs)

        %{"concept" => concept} ->
          create_game_with_concept(attrs, concept)

        nil ->
          create_game_with_placed_incarnation(attrs)
      end

    case case_result do
      {:ok, game} -> {:ok, game}
      {:error, :no_placed_incarnation_available} -> {:error, "No placed incarnation available"}
      {:error, :no_incarnation_with_concept_available} -> {:error, "No incarnation with the specified concept available"}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp create_game_with_placed_incarnation(attrs) do
    case get_random_incarnation(%{"placed" => true}) do
      nil ->
        {:error, :no_placed_incarnation_available}

      incarnation ->
        %Game{}
        |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
        |> Repo.insert()
    end
  end

  defp create_game_with_concept(attrs, concept) do
    concept_data = concepts_yaml()[concept]

    if concept_data["placed"] == false do
      create_game_with_new_incarnation(attrs, concept)
    else
      case get_random_incarnation(%{"concept" => concept}) do
        nil ->
          {:error, :no_incarnation_with_concept_available}

        incarnation ->
          %Game{}
          |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
          |> Repo.insert()
      end
    end
  end

  defp create_game_with_new_incarnation(attrs, concept \\ nil) do
    {concept_key, concept_data} =
      if concept do
        {concept, concepts_yaml()[concept]}
      else
        choose_unplaced_concept()
      end

    answers = generate_answers(concept_data)

    {:ok, incarnation} =
      create_incarnation(%{
        concept: concept_key,
        mask: concept_data["instructions"],
        answers: answers,
        placed: false
      })

    %Game{}
    |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
    |> Repo.insert()
  end

  defp create_incarnation(attrs) do
    %Incarnation{}
    |> Incarnation.changeset(attrs)
    |> Repo.insert()
  end

  defp choose_unplaced_concept do
    concepts_yaml()
    |> Enum.filter(fn {_, v} -> v["placed"] == false end)
    |> Enum.random()
  end

  defp generate_answers(concept) do
    options = concept["options"]
    length = Enum.random(4..6)

    1..length
    |> Enum.reduce([], fn i, acc ->
      available_options = if i > 1, do: options, else: options -- [List.last(acc)]
      [Enum.random(available_options) | acc]
    end)
    |> Enum.reverse()
  end

  defp get_random_incarnation(filter) do
    query = from(i in Incarnation)

    query =
      case filter do
        %{"placed" => placed} when is_boolean(placed) ->
          where(query, [i], i.placed == ^placed)

        %{"concept" => concept} when is_binary(concept) ->
          where(query, [i], i.concept == ^concept)

        nil ->
          query
      end

    query
    |> Repo.all()
    |> case do
      [] -> nil
      incarnations -> Enum.random(incarnations)
    end
  end

  @doc """
  Returns the list of incarnations.

  ## Examples

      iex> list_incarnations()
      [%Incarnation{}, ...]

  """
  def list_incarnations do
    Incarnation |> Repo.all() |> Repo.preload(region: [:parent])
  end

  @doc """
  Gets a single incarnation.

  Raises `Ecto.NoResultsError` if the Incarnation does not exist.

  ## Examples

      iex> get_incarnation!(123)
      %Incarnation{}

      iex> get_incarnation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_incarnation!(id), do: Repo.get!(Incarnation, id)

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

    correct = check_answer_correctness(incarnation, answer_text)

    attrs = %{
      "answer" => answer_text,
      "correct" => correct,
      "game_id" => game_id
    }

    %Answer{}
    |> Answer.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, answer} ->
        check_and_update_game_winner(game, answer)
        {:ok, Repo.preload(answer, game: [:answers, :incarnation])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates an answer.

  ## Examples

      iex> update_answer(%{id: id, field: new_value})
      {:ok, %Answer{}}

      iex> update_answer(%{id: id, field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_answer(%{"id" => id, "answer" => answer_text}) do
    answer = get_answer!(id)
    game = get_game!(answer.game_id)
    incarnation = game.incarnation

    cond do
      incarnation.placed ->
        {:error, :cannot_update_placed_incarnation_answer}

      not answer.correct ->
        {:error, :cannot_update_incorrect_answer}

      true ->
        correct = check_answer_correctness(incarnation, answer_text)

        attrs = %{
          "answer" => answer_text,
          "correct" => correct
        }

        answer
        |> Answer.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_answer} ->
            game = check_and_update_game_winner(game, updated_answer)
            {:ok, Repo.preload(updated_answer, game: [:answers, :incarnation])}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def get_game_progress(game) do
    correct_answers =
      game.answers
      |> Enum.uniq_by(& &1.answer)
      |> Enum.count(& &1.correct)

    total_answers = length(game.incarnation.answers)

    %{
      correct_answers: correct_answers,
      total_answers: total_answers,
      complete: game.winner_answer_id != nil
    }
  end

  defp check_answer_correctness(%Incarnation{concept: "fill_in_the_blank", answers: [correct_answer]}, answer_text) do
    String.downcase(String.trim(correct_answer)) == String.downcase(String.trim(answer_text))
  end

  defp check_answer_correctness(%Incarnation{concept: "bluetooth_collector", answers: correct_answers}, answer_text) do
    answer_text in correct_answers
  end

  defp check_answer_correctness(%Incarnation{concept: "code_collector", answers: correct_answers}, answer_text) do
    answer_text in correct_answers
  end

  defp check_answer_correctness(%Incarnation{concept: concept, answers: expected_answers}, answer_text)
       when concept in ["orientation_memory", "cardinal_memory"] do
    expected_answer = Enum.join(expected_answers, "|")

    String.starts_with?(expected_answer, answer_text) and
      String.length(answer_text) <= String.length(expected_answer)
  end

  defp single_answer_game?(%Incarnation{concept: "fill_in_the_blank"}), do: true
  defp single_answer_game?(_), do: false

  defp update_game_winner(game, answer) do
    game
    |> Game.changeset(%{winner_answer_id: answer.id})
    |> Repo.update!()
  end

  # New helper function to check and update game winner
  defp check_and_update_game_winner(game, answer) do
    if answer.correct and check_win_condition(game, answer) do
      update_game_winner(game, answer)
    else
      game
    end
  end

  # New helper function to check win condition
  defp check_win_condition(game, answer) do
    case game.incarnation.concept do
      "fill_in_the_blank" ->
        true

      "bluetooth_collector" ->
        Enum.count(game.answers, & &1.correct) == length(game.incarnation.answers)

      "code_collector" ->
        Enum.count(game.answers, & &1.correct) == length(game.incarnation.answers)

      "orientation_memory" ->
        answer.answer == Enum.join(game.incarnation.answers, "|")

      "cardinal_memory" ->
        answer.answer == Enum.join(game.incarnation.answers, "|")

      _ ->
        false
    end
  end
end
