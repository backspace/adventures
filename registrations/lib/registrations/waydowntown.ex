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

        %{"position" => {latitude, longitude}} ->
          create_game_with_nearest_incarnation(attrs, latitude, longitude)

        %{"concept" => concept} ->
          create_game_with_concept(attrs, concept)

        %{"incarnation_id" => id} ->
          create_game_with_specific_incarnation(attrs, id)

        nil ->
          create_game_with_placed_incarnation(attrs)
      end

    case case_result do
      {:ok, game} ->
        {:ok, game}

      {:error, error_message} when is_binary(error_message) ->
        changeset =
          %Game{}
          |> Game.changeset(attrs)
          |> Ecto.Changeset.add_error(:base, error_message)

        {:error, changeset}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_game_with_placed_incarnation(attrs) do
    case get_random_incarnation(%{"placed" => true}) do
      nil ->
        {:error, "No placed incarnation available"}

      incarnation ->
        %Game{}
        |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
        |> Repo.insert()
    end
  end

  defp create_game_with_nearest_incarnation(attrs, latitude, longitude) do
    case get_nearest_incarnation(latitude, longitude) do
      nil ->
        {:error, "No incarnation found near the specified position"}

      incarnation ->
        %Game{}
        |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
        |> Repo.insert()
    end
  end

  defp get_nearest_incarnation(latitude, longitude) do
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    Incarnation
    |> join(:inner, [i], r in assoc(i, :region))
    |> where([i], i.placed == true)
    |> order_by([i, r], fragment("ST_Distance(?, ?)", r.geom, ^point))
    |> limit(1)
    |> Repo.one()
  end

  defp create_game_with_concept(attrs, concept) do
    concept_data = concepts_yaml()[concept]

    if concept_data["placed"] == false do
      create_game_with_new_incarnation(attrs, concept)
    else
      case get_random_incarnation(%{"concept" => concept, "placed" => true}) do
        nil ->
          {:error, "No incarnation with the specified concept available"}

        incarnation ->
          %Game{}
          |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
          |> Repo.insert()
      end
    end
  end

  defp create_game_with_specific_incarnation(attrs, incarnation_id) do
    case Repo.get(Incarnation, incarnation_id) do
      nil ->
        {:error, "Specified incarnation not found"}

      incarnation ->
        %Game{}
        |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
        |> Repo.insert()
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
        description: concept_data["instructions"],
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
      Enum.reduce(filter, query, fn
        {"placed", placed}, query when is_boolean(placed) ->
          where(query, [i], i.placed == ^placed)

        {"concept", concept}, query when is_binary(concept) ->
          where(query, [i], i.concept == ^concept)

        _, query ->
          query
      end)

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

    cond do
      is_nil(game.started_at) ->
        {:error, "Game has not been started"}

      game_expired?(game) ->
        {:error, "Game has expired"}

      true ->
        incarnation = game.incarnation

        case incarnation.concept do
          "string_collector" ->
            normalized_answer = normalize_string(answer_text)
            existing_answers = Enum.map(game.answers, &normalize_string(&1.answer))

            if normalized_answer in existing_answers do
              changeset =
                %Answer{}
                |> Answer.changeset(%{"answer" => answer_text, "game_id" => game_id})
                |> Ecto.Changeset.add_error(:detail, "Answer already submitted")

              {:error, changeset}
            else
              create_answer_helper(answer_text, game_id, incarnation)
            end

          "food_court_frenzy" ->
            [label, _] = String.split(answer_text, "|")
            known_labels = incarnation_answer_labels(incarnation)

            cond do
              label not in known_labels ->
                changeset =
                  %Answer{}
                  |> Answer.changeset(%{"answer" => answer_text, "game_id" => game_id})
                  |> Ecto.Changeset.add_error(:detail, "Unknown label: #{label}")

                {:error, changeset}

              Enum.any?(game.answers, fn a -> a.correct and String.starts_with?(a.answer, label <> "|") end) ->
                changeset =
                  %Answer{}
                  |> Answer.changeset(%{"answer" => answer_text, "game_id" => game_id})
                  |> Ecto.Changeset.add_error(:detail, "Answer already submitted for label: #{label}")

                {:error, changeset}

              true ->
                create_answer_helper(answer_text, game_id, incarnation)
            end

          _ ->
            create_answer_helper(answer_text, game_id, incarnation)
        end
    end
  end

  def incarnation_answer_labels(incarnation) do
    Enum.map(incarnation.answers, fn a -> List.first(String.split(a, "|")) end)
  end

  defp create_answer_helper(answer_text, game_id, incarnation) do
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
        game = get_game!(game_id)
        check_and_update_game_winner(game, answer)
        {:ok, Repo.preload(answer, game: [:answers, :incarnation])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp game_expired?(%Game{started_at: started_at, incarnation: %Incarnation{duration_seconds: duration}})
       when not is_nil(started_at) and not is_nil(duration) do
    expiration_time = DateTime.add(started_at, duration, :second)
    DateTime.after?(DateTime.utc_now(), expiration_time)
  end

  defp game_expired?(_), do: false

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

  defp check_answer_correctness(%Incarnation{concept: concept, answers: [correct_answer]}, answer_text)
       when concept in ["fill_in_the_blank", "count_the_items"] do
    normalize_string(correct_answer) == normalize_string(answer_text)
  end

  defp check_answer_correctness(%Incarnation{concept: concept, answers: correct_answers}, answer_text)
       when concept in ["bluetooth_collector", "code_collector", "string_collector"] do
    normalized_answer = if concept == "string_collector", do: normalize_string(answer_text), else: answer_text

    correct_answers =
      if concept == "string_collector", do: Enum.map(correct_answers, &normalize_string(&1)), else: correct_answers

    normalized_answer in correct_answers
  end

  defp check_answer_correctness(%Incarnation{concept: concept, answers: expected_answers}, answer_text)
       when concept in ["orientation_memory", "cardinal_memory"] do
    expected_answer = Enum.join(expected_answers, "|")

    String.starts_with?(expected_answer, answer_text) and
      String.length(answer_text) <= String.length(expected_answer)
  end

  defp check_answer_correctness(%Incarnation{concept: "food_court_frenzy", answers: correct_answers}, answer_text) do
    [label, price] = String.split(answer_text, "|")
    correct_answer = Enum.find(correct_answers, fn ca -> String.starts_with?(ca, label <> "|") end)
    correct_answer == answer_text
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

      "count_the_items" ->
        true

      concept when concept in ["bluetooth_collector", "code_collector", "string_collector"] ->
        game = get_game!(game.id)
        Enum.count(game.answers, & &1.correct) == length(game.incarnation.answers)

      "orientation_memory" ->
        answer.answer == Enum.join(game.incarnation.answers, "|")

      "cardinal_memory" ->
        answer.answer == Enum.join(game.incarnation.answers, "|")

      "food_court_frenzy" ->
        game = get_game!(game.id)
        correct_answers = Enum.count(game.answers, & &1.correct)
        total_answers = length(game.incarnation.answers)
        correct_answers == total_answers

      _ ->
        false
    end
  end

  defp normalize_string(string) do
    string
    |> String.trim()
    |> String.downcase()
  end

  def start_game(%Game{} = game) do
    case game.started_at do
      nil ->
        game
        |> Game.changeset(%{started_at: DateTime.utc_now()})
        |> Repo.update()

      _ ->
        {:error, "Game already started"}
    end
  end
end
