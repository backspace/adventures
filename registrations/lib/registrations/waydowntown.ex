defmodule Registrations.Waydowntown do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Registrations.Repo
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Run
  alias Registrations.Waydowntown.Specification
  alias Registrations.Waydowntown.Submission

  defp concepts_yaml do
    YamlElixir.read_from_file!(Path.join(:code.priv_dir(:registrations), "concepts.yaml"))
  end

  def list_runs do
    Run |> Repo.all() |> Repo.preload(run_preloads())
  end

  def get_run!(id) do
    Run
    |> Repo.get!(id)
    |> Repo.preload(run_preloads())
  end

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
          create_run_with_placed_specification(attrs)
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
        {:error, "Specification not found"}

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

  def list_specifications do
    Specification |> Repo.all() |> Repo.preload(region: [parent: [parent: [:parent]]])
  end

  def get_specification!(id), do: Repo.get!(Specification, id)

  def get_submission!(id), do: Submission |> Repo.get!(id) |> Repo.preload(submission_preloads())

  def create_submission(%{"submission" => submission_text, "run_id" => run_id} = params) do
    answer_id = Map.get(params, "answer_id")

    run = get_run!(run_id)

    cond do
      is_nil(run.started_at) ->
        {:error, "Run has not been started"}

      run_expired?(run) ->
        {:error, "Run has expired"}

      concept_requires_paired_answer?(run.specification.concept) and
          (is_nil(answer_id) or answer_id not in Enum.map(run.specification.answers, & &1.id)) ->
        {:error, "Answer does not belong to specification"}

      true ->
        specification = run.specification

        cond do
          specification.concept == "string_collector" ->
            check_for_duplicate_normalised_submission(run, submission_text)

          specification.concept in ["food_court_frenzy", "fill_in_the_blank", "count_the_items"] ->
            check_for_paired_answer(run, specification, submission_text, answer_id)

          specification.concept in ["orientation_memory", "cardinal_memory"] ->
            check_for_ordered_answer(run, specification, submission_text, answer_id)

          true ->
            insert_submission(run, submission_text, answer_id)
        end
    end
  end

  defp concept_requires_paired_answer?(concept) do
    concept in [
      "orientation_memory",
      "cardinal_memory",
      "food_court_frenzy",
      "fill_in_the_blank",
      "count_the_items"
    ]
  end

  defp check_for_duplicate_normalised_submission(run, submission_text) do
    normalized_submission = normalize_string(submission_text)
    existing_submissions = Enum.map(run.submissions, &normalize_string(&1.submission))

    if normalized_submission in existing_submissions do
      {:error, "Submission already submitted"}
    else
      insert_submission(run, submission_text)
    end
  end

  defp check_for_paired_answer(run, specification, submission_text, answer_id) do
    answer_with_submitted_id = Enum.find(specification.answers, fn a -> a.id == answer_id end)

    cond do
      is_nil(answer_id) ->
        {:error, "Answer is required"}

      is_nil(answer_with_submitted_id) ->
        {:error, "Unknown answer: #{answer_id}"}

      Enum.any?(run.submissions, fn s -> s.correct && s.answer_id end) ->
        {:error, "Submission already exists for label: #{answer_with_submitted_id.label}"}

      Enum.any?(run.submissions, fn s -> s.submission == submission_text end) ->
        {:error, "Submission already submitted"}

      true ->
        insert_submission(run, submission_text, answer_id)
    end
  end

  def check_for_ordered_answer(run, specification, submission_text, answer_id) do
    answer_with_submitted_id = Enum.find(specification.answers, fn a -> a.id == answer_id end)
    latest_submission = run.submissions |> Enum.sort_by(&{&1.inserted_at, &1.answer.order}, :desc) |> List.first()

    expected_answer_order =
      cond do
        is_nil(latest_submission) ->
          1

        latest_submission.correct ->
          latest_submission.answer.order + 1

        true ->
          1
      end

    if answer_with_submitted_id.order == expected_answer_order do
      insert_submission(run, submission_text, answer_id)
    else
      {:error,
       "Expected submission for answer of order #{expected_answer_order}, id #{Enum.find(specification.answers, fn a -> a.order == expected_answer_order end).id}"}
    end
  end

  # FIXME rename
  defp insert_submission(run, submission_text, answer_id \\ nil) do
    correct = check_submission_correctness(run, submission_text, answer_id)

    attrs = %{
      "submission" => submission_text,
      "correct" => correct,
      "run_id" => run.id,
      "answer_id" => answer_id
    }

    %Submission{}
    |> Submission.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, submission} ->
        submission = Repo.preload(submission, submission_preloads())
        check_and_update_run_winner(run, submission)
        submission = get_submission!(submission.id)
        {:ok, submission}

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

  def get_run_progress(run) do
    correct_submissions =
      run.submissions
      |> Enum.uniq_by(& &1.answer)
      |> Enum.count(& &1.correct)

    total_answers = length(run.specification.answers)

    %{
      correct_submissions: correct_submissions,
      total_answers: total_answers,
      complete: run.winner_submission_id != nil
    }
  end

  defp check_submission_correctness(
         %Run{specification: %Specification{concept: concept, answers: [%Answer{answer: correct_answer}]}},
         submission_text,
         _answer_id
       )
       when concept in ["fill_in_the_blank", "count_the_items"] do
    normalize_string(correct_answer) == normalize_string(submission_text)
  end

  defp check_submission_correctness(
         %Run{specification: %Specification{concept: concept, answers: answers}},
         submission_text,
         _answer_id
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
         submission_text,
         answer_id
       )
       when concept in ["orientation_memory", "cardinal_memory"] do
    answer = Enum.find(expected_answers, fn a -> a.id == answer_id end)

    submission_text == answer.answer
  end

  defp check_submission_correctness(
         %Run{specification: %Specification{concept: "food_court_frenzy", answers: correct_answers}},
         submission_text,
         answer_id
       ) do
    correct_answer = Enum.find(correct_answers, fn ca -> ca.id == answer_id end)
    normalize_string(correct_answer.answer) == normalize_string(submission_text)
  end

  defp update_run_winner(run, submission) do
    run
    |> Run.changeset(%{winner_submission_id: submission.id})
    |> Repo.update!()
  end

  defp check_and_update_run_winner(run, submission) do
    run = get_run!(run.id)

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

      concept when concept in ["bluetooth_collector", "code_collector", "string_collector", "food_court_frenzy"] ->
        Enum.count(run.submissions, & &1.correct) == length(run.specification.answers)

      # FIXME these all need fixing, and order is missing
      "orientation_memory" ->
        check_ordered_win_condition(run, submission)

      "cardinal_memory" ->
        check_ordered_win_condition(run, submission)

      _ ->
        false
    end
  end

  defp check_ordered_win_condition(run, submission) do
    answer_count = length(run.specification.answers)
    submission.answer.order == answer_count
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

  defp run_preloads do
    [submissions: [:answer], specification: [:answers, region: [parent: [parent: [:parent]]]]]
  end

  defp submission_preloads do
    [:answer, run: [specification: [:answers], submissions: [:answer]]]
  end
end
