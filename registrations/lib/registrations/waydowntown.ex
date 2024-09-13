defmodule Registrations.Waydowntown do
  @moduledoc """
  The Waydowntown context.
  """

  import Ecto.Query, warn: false

  alias Registrations.Repo
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Run
  alias Registrations.Waydowntown.Specification
  alias Registrations.Waydowntown.Submission

  @doc false
  defp concepts_yaml do
    YamlElixir.read_from_file!(Path.join(:code.priv_dir(:registrations), "concepts.yaml"))
  end

  @doc """
  Returns the list of runs.

  ## Examples

      iex> list_runs()
      [%Run{}, ...]

  """
  def list_runs do
    Run |> Repo.all() |> Repo.preload(specification: [region: [parent: [parent: [:parent]]]])
  end

  @doc """
  Gets a single run.

  Raises `Ecto.NoResultsError` if the Run does not exist.

  ## Examples

      iex> get_run!(123)
      %Run{}

      iex> get_run!(456)
      ** (Ecto.NoResultsError)

  """
  def get_run!(id) do
    Run
    |> Repo.get!(id)
    |> Repo.preload([:submissions, specification: [:answers]])
  end

  @doc """
  Creates a run.

  ## Examples

      iex> create_run(%{field: value})
      {:ok, %Run{}}

      iex> create_run(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_run(attrs \\ %{}, specification_filter \\ nil) do
    case_result =
      case specification_filter do
        %{"placed" => "false"} ->
          create_run_with_new_specification(attrs)

        %{"placed" => "true"} ->
          create_run_with_placed_specification(attrs)

        %{"position" => {latitude, longitude}} ->
          create_run_with_nearest_specification(attrs, latitude, longitude)

        %{"concept" => concept} ->
          create_run_with_concept(attrs, concept)

        %{"specification_id" => id} ->
          create_run_with_specific_specification(attrs, id)

        nil ->
          create_run_with_new_specification(attrs)
      end

    case case_result do
      {:ok, run} ->
        {:ok, run}

      {:error, error_message} when is_binary(error_message) ->
        changeset =
          %Run{}
          |> Run.changeset(attrs)
          |> Ecto.Changeset.add_error(:base, error_message)

        {:error, changeset}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_run_with_placed_specification(attrs) do
    case get_random_specification(%{"placed" => true}) do
      nil ->
        {:error, "No placed specification available"}

      specification ->
        %Run{}
        |> Run.changeset(Map.put(attrs, "specification_id", specification.id))
        |> Repo.insert()
    end
  end

  defp create_run_with_nearest_specification(attrs, latitude, longitude) do
    case get_nearest_specification(latitude, longitude) do
      nil ->
        {:error, "No specification found near the specified position"}

      specification ->
        %Run{}
        |> Run.changeset(Map.put(attrs, "specification_id", specification.id))
        |> Repo.insert()
    end
  end

  defp get_nearest_specification(latitude, longitude) do
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    Specification
    |> join(:inner, [i], r in assoc(i, :region))
    |> where([i], i.placed == true)
    |> order_by([i, r], fragment("ST_Distance(?, ?)", r.geom, ^point))
    |> limit(1)
    |> Repo.one()
  end

  defp create_run_with_concept(attrs, concept) do
    concept_data = concepts_yaml()[concept]

    if concept_data["placed"] == false do
      create_run_with_new_specification(attrs, concept)
    else
      case get_random_specification(%{"concept" => concept, "placed" => true}) do
        nil ->
          {:error, "No specification with the specified concept available"}

        specification ->
          %Run{}
          |> Run.changeset(Map.put(attrs, "specification_id", specification.id))
          |> Repo.insert()
      end
    end
  end

  defp create_run_with_specific_specification(attrs, specification_id) do
    case Repo.get(Specification, specification_id) do
      nil ->
        {:error, "Specified specification not found"}

      specification ->
        %Run{}
        |> Run.changeset(Map.put(attrs, "specification_id", specification.id))
        |> Repo.insert()
    end
  end

  defp create_run_with_new_specification(attrs, concept \\ nil) do
    {concept_key, concept_data} =
      if concept do
        {concept, concepts_yaml()[concept]}
      else
        choose_unplaced_concept()
      end

    answers = generate_answers(concept_data)

    {:ok, specification} =
      create_specification(%{
        concept: concept_key,
        task_description: concept_data["instructions"],
        answers: Enum.map(answers, &%Answer{answer: &1})
      })

    %Run{}
    |> Run.changeset(Map.put(attrs, "specification_id", specification.id))
    |> Repo.insert()
  end

  defp create_specification(attrs) do
    %Specification{}
    |> Specification.changeset(attrs)
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

  defp get_random_specification(filter) do
    query = from(i in Specification)

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
      specifications -> Enum.random(specifications)
    end
  end

  @doc """
  Returns the list of specifications.

  ## Examples

      iex> list_specifications()
      [%Specification{}, ...]

  """
  def list_specifications do
    Specification |> Repo.all() |> Repo.preload(region: [parent: [parent: [:parent]]])
  end

  @doc """
  Gets a single specification.

  Raises `Ecto.NoResultsError` if the Specification does not exist.

  ## Examples

      iex> get_specification!(123)
      %Specification{}

      iex> get_specification!(456)
      ** (Ecto.NoResultsError)

  """
  def get_specification!(id), do: Repo.get!(Specification, id)

  @doc """
  Gets a single submission.

  Raises `Ecto.NoResultsError` if the Submission does not exist.

  ## Examples

      iex> get_submission!(123)
      %Submission{}

      iex> get_submission!(456)
      ** (Ecto.NoResultsError)

  """
  def get_submission!(id), do: Repo.get!(Submission, id)

  @doc """
  Creates a submission.

  ## Examples

      iex> create_submission(%{field: value})
      {:ok, %Submission{}}

      iex> create_submission(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_submission(%{"submission" => submission_text, "run_id" => run_id}) do
    run = get_run!(run_id)

    cond do
      is_nil(run.started_at) ->
        {:error, "Run has not been started"}

      run_expired?(run) ->
        {:error, "Run has expired"}

      true ->
        specification = run.specification

        case specification.concept do
          "string_collector" ->
            normalized_submission = normalize_string(submission_text)
            existing_submissions = Enum.map(run.submissions, &normalize_string(&1.submission))

            if normalized_submission in existing_submissions do
              changeset =
                %Submission{}
                |> Submission.changeset(%{"submission" => submission_text, "run_id" => run_id})
                |> Ecto.Changeset.add_error(:detail, "Submission already submitted")

              {:error, changeset}
            else
              create_submission_helper(submission_text, run_id, specification)
            end

          # FIXME handle submissions with attached answers
          "food_court_frenzy" ->
            [label, _] = String.split(submission_text, "|")
            known_labels = specification_answer_labels(specification)

            cond do
              label not in known_labels ->
                changeset =
                  %Submission{}
                  |> Submission.changeset(%{"submission" => submission_text, "run_id" => run_id})
                  |> Ecto.Changeset.add_error(:detail, "Unknown label: #{label}")

                {:error, changeset}

              Enum.any?(run.submissions, fn s -> s.submission == submission_text end) ->
                changeset =
                  %Submission{}
                  |> Submission.changeset(%{"submission" => submission_text, "run_id" => run_id})
                  |> Ecto.Changeset.add_error(:detail, "Submission already submitted")

                {:error, changeset}

              true ->
                create_submission_helper(submission_text, run_id, specification)
            end

          _ ->
            create_submission_helper(submission_text, run_id, specification)
        end
    end
  end

  defp specification_answer_labels(specification) do
    Enum.map(specification.answers, fn a -> a.label end)
  end

  defp create_submission_helper(submission_text, run_id, specification) do
    correct = check_submission_correctness(specification, submission_text)

    attrs = %{
      "submission" => submission_text,
      "correct" => correct,
      "run_id" => run_id
    }

    %Submission{}
    |> Submission.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, submission} ->
        run = get_run!(run_id)
        check_and_update_run_winner(run, submission)
        {:ok, Repo.preload(submission, run: [:submissions, :specification])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp run_expired?(%Run{started_at: started_at, specification: %Specification{duration: duration}})
       when not is_nil(started_at) and not is_nil(duration) do
    expiration_time = DateTime.add(started_at, duration, :second)
    DateTime.after?(DateTime.utc_now(), expiration_time)
  end

  defp run_expired?(_), do: false

  @doc """
  Updates a submission.

  ## Examples

      iex> update_submission(%{id: id, field: new_value})
      {:ok, %Submission{}}

      iex> update_submission(%{id: id, field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_submission(%{"id" => id, "submission" => submission_text}) do
    submission = get_submission!(id)
    run = get_run!(submission.run_id)
    specification = run.specification

    cond do
      specification.placed ->
        {:error, :cannot_update_placed_specification_submission}

      not submission.correct ->
        {:error, :cannot_update_incorrect_submission}

      true ->
        correct = check_submission_correctness(run, submission_text)

        attrs = %{
          "submission" => submission_text,
          "correct" => correct
        }

        submission
        |> Submission.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_submission} ->
            check_and_update_run_winner(run, updated_submission)
            {:ok, Repo.preload(updated_submission, run: [:submissions, :specification])}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def get_run_progress(run) do
    correct_submissions =
      run.submissions
      |> Enum.uniq_by(& &1.answer)
      |> Enum.count(& &1.correct)

    total_submissions = length(run.submissions)

    %{
      correct_submissions: correct_submissions,
      total_submissions: total_submissions,
      complete: run.winner_submission_id != nil
    }
  end

  defp check_submission_correctness(
         %Run{specification: %Specification{concept: concept, answers: [%Answer{answer: correct_answer}]}},
         submission_text
       )
       when concept in ["fill_in_the_blank", "count_the_items"] do
    normalize_string(correct_answer) == normalize_string(submission_text)
  end

  defp check_submission_correctness(
         %Run{specification: %Specification{concept: concept, answers: answers}},
         submission_text
       )
       when concept in ["bluetooth_collector", "code_collector", "string_collector"] do
    normalized_answer = if concept == "string_collector", do: normalize_string(submission_text), else: submission_text

    correct_answers =
      if concept == "string_collector",
        do: Enum.map(answers, &normalize_string(&1.answer)),
        else: Enum.map(answers, & &1.answer)

    normalized_answer in correct_answers
  end

  defp check_submission_correctness(
         %Run{specification: %Specification{concept: concept, answers: expected_answers}},
         submission_text
       )
       when concept in ["orientation_memory", "cardinal_memory"] do
    expected_answer = Enum.join(expected_answers, "|")

    String.starts_with?(expected_answer, submission_text) and
      String.length(submission_text) <= String.length(expected_answer)
  end

  # FIXME needs adjustment for checking answer relation
  defp check_submission_correctness(
         %Run{specification: %Specification{concept: "food_court_frenzy", answers: correct_answers}},
         submission_text
       ) do
    [label, price] = String.split(submission_text, "|")
    correct_answer = Enum.find(correct_answers, fn ca -> String.starts_with?(ca.answer, label) end)
    correct_answer != nil
  end

  defp single_answer_run?(%Run{specification: %Specification{concept: "fill_in_the_blank"}}), do: true
  defp single_answer_run?(_), do: false

  defp update_run_winner(run, submission) do
    run
    |> Run.changeset(%{winner_submission_id: submission.id})
    |> Repo.update!()
  end

  defp check_and_update_run_winner(run, submission) do
    if submission.correct and check_win_condition(run, submission) do
      update_run_winner(run, submission)
    else
      run
    end
  end

  defp check_win_condition(run, submission) do
    case run.specification.concept do
      "fill_in_the_blank" ->
        true

      "count_the_items" ->
        true

      concept when concept in ["bluetooth_collector", "code_collector", "string_collector"] ->
        run = get_run!(run.id)
        Enum.count(run.submissions, & &1.correct) == length(run.specification.answers)

      # FIXME these all need fixing, and order is missing
      "orientation_memory" ->
        submission.answer == Enum.join(run.specification.answers, "|")

      "cardinal_memory" ->
        submission.answer == Enum.join(run.specification.answers, "|")

      "food_court_frenzy" ->
        run = get_run!(run.id)
        correct_submissions = Enum.count(run.submissions, & &1.correct)
        total_answers = length(run.specification.answers)
        correct_submissions == total_answers

      _ ->
        false
    end
  end

  defp normalize_string(string) do
    string
    |> String.trim()
    |> String.downcase()
  end

  def start_run(%Run{} = run) do
    case run.started_at do
      nil ->
        run
        |> Run.changeset(%{started_at: DateTime.utc_now()})
        |> Repo.update()

      _ ->
        {:error, "Run already started"}
    end
  end
end
