defmodule Registrations.Waydowntown do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Registrations.Repo
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Participation
  alias Registrations.Waydowntown.Region
  alias Registrations.Waydowntown.Reveal
  alias Registrations.Waydowntown.Run
  alias Registrations.Waydowntown.Specification
  alias Registrations.Waydowntown.Submission
  alias RegistrationsWeb.User

  def update_user(user, attrs) do
    user
    |> User.name_changeset(attrs)
    |> Repo.update()
  end

  defp concepts_yaml do
    ConCache.get_or_store(:registrations_cache, :concepts_yaml, fn ->
      YamlElixir.read_from_file!(Path.join(:code.priv_dir(:registrations), "concepts.yaml"))
    end)
  end

  def get_known_concepts do
    Map.keys(concepts_yaml())
  end

  def concept_is_placed(concept) do
    !(concepts_yaml()[concept]["placeless"] == true)
  end

  def list_regions do
    Region |> Repo.all() |> Repo.preload(region_preloads())
  end

  def get_nearest_regions(latitude, longitude, limit) do
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    Region
    |> select([r], %{r | distance: fragment("ST_Distance(?, ?, true)", r.geom, ^point)})
    |> order_by([r], fragment("ST_Distance(?, ?)", r.geom, ^point))
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(region_preloads())
  end

  def get_region!(id), do: Repo.get!(Region, id)

  def create_region(attrs) do
    %Region{}
    |> Region.changeset(attrs)
    |> Repo.insert()
  end

  def update_region(%Region{} = region, attrs) do
    region
    |> Region.changeset(attrs)
    |> Repo.update()
  end

  def delete_region(%Region{} = region) do
    Repo.delete(region)
  end

  defp region_preloads do
    [parent: [parent: [:parent]]]
  end

  def list_runs(filters \\ %{}) do
    Run
    |> filter_runs_query(filters)
    |> Repo.all()
    # FIXME Preloads involving the user preclude this approach
    |> Repo.preload(run_preloads())
    |> Repo.preload(participations: [run: run_preloads()])
    |> Repo.preload([participations: [:user]], prefix: "public")
  end

  defp filter_runs_query(query, filters) do
    Enum.reduce(filters, query, fn
      {"started", "true"}, query ->
        from(r in query, where: not is_nil(r.started_at))

      {"started", "false"}, query ->
        from(r in query, where: is_nil(r.started_at))

      _, query ->
        query
    end)
  end

  @spec get_run!(any()) :: nil | [%{optional(atom()) => any()}] | %{optional(atom()) => any()}
  def get_run!(id) do
    Run
    |> Repo.get!(id)
    |> Repo.preload(run_preloads())
    |> Repo.preload(participations: [run: run_preloads()])
    |> Repo.preload([participations: [:user]], prefix: "public")
    |> Repo.preload([submissions: [:creator]], prefix: "public")
  end

  def create_run(current_user, attrs \\ %{}, specification_filter \\ nil) do
    with {:ok, run} <- construct_run(attrs, specification_filter),
         {:ok, run} <- Repo.insert(run),
         {:ok, _participation} <- create_participation(current_user, run) do
      {:ok,
       run
       |> Repo.preload(run_preloads())
       |> Repo.preload(participations: [run: run_preloads()])
       |> Repo.preload([participations: [:user]], prefix: "public")}
    else
      {:error, changeset} ->
        {:error, changeset}

      {:error, error_message} when is_binary(error_message) ->
        changeset =
          %Run{}
          |> Run.changeset(attrs)
          |> Ecto.Changeset.add_error(:base, error_message)

        {:error, changeset}
    end
  end

  defp construct_run(attrs, specification_filter) do
    case specification_filter do
      %{"placed" => "false"} ->
        construct_run_with_new_specification(attrs)

      %{"placed" => "true"} ->
        construct_run_with_placed_specification(attrs)

      %{"position" => {latitude, longitude}} ->
        construct_run_with_nearest_specification(attrs, latitude, longitude)

      %{"concept" => concept} ->
        construct_run_with_concept(attrs, concept)

      %{"specification_id" => id} ->
        construct_run_with_specific_specification(attrs, id)

      nil ->
        construct_run_with_placed_specification(attrs)
    end
  end

  defp construct_run_with_placed_specification(attrs) do
    case get_random_specification(%{"placed" => true}) do
      nil ->
        {:error, "No placed specification available"}

      specification ->
        {:ok, Run.changeset(%Run{}, Map.put(attrs, "specification_id", specification.id))}
    end
  end

  defp construct_run_with_nearest_specification(attrs, latitude, longitude) do
    case get_nearest_specification(latitude, longitude) do
      nil ->
        {:error, "No specification found near the specified position"}

      specification ->
        {:ok, Run.changeset(%Run{}, Map.put(attrs, "specification_id", specification.id))}
    end
  end

  defp construct_run_with_concept(attrs, concept) do
    concept_data = concepts_yaml()[concept]

    if concept_data["placeless"] == true do
      construct_run_with_new_specification(attrs, concept)
    else
      case get_random_specification(%{"concept" => concept, "placed" => true}) do
        nil ->
          {:error, "No specification with the specified concept available"}

        specification ->
          {:ok, Run.changeset(%Run{}, Map.put(attrs, "specification_id", specification.id))}
      end
    end
  end

  defp construct_run_with_specific_specification(attrs, specification_id) do
    case Repo.get(Specification, specification_id) do
      nil ->
        {:error, "Specification not found"}

      specification ->
        {:ok, Run.changeset(%Run{}, Map.put(attrs, "specification_id", specification.id))}
    end
  end

  defp construct_run_with_new_specification(attrs, concept \\ nil) do
    {concept_key, concept_data} =
      if concept do
        {concept, concepts_yaml()[concept]}
      else
        choose_unplaced_concept()
      end

    answers = generate_answers(concept_data)

    with {:ok, specification} <-
           create_specification(%{
             concept: concept_key,
             task_description: concept_data["instructions"]
           }),
         {:ok, _} <- create_answers(specification, answers) do
      {:ok, Run.changeset(%Run{}, Map.put(attrs, "specification_id", specification.id))}
    end
  end

  def join_run(user, run_id, conn) do
    run = get_run!(run_id)

    if Enum.any?(run.participations, fn p -> p.user_id == user.id end) do
      {:error, "User is already a participant in this run"}
    else
      %Participation{}
      |> Participation.changeset(%{user_id: user.id, run_id: run.id})
      |> Repo.insert()
      |> case do
        {:ok, participation} ->
          broadcast_participation_update(participation, conn)
          {:ok, participation |> Repo.preload(run: run_preloads()) |> Repo.preload(:user, prefix: "public")}

        error ->
          error
      end
    end
  end

  defp create_specification(attrs) do
    %Specification{}
    |> Specification.changeset(attrs)
    |> Repo.insert()
  end

  defp create_answers(specification, answers) do
    answer_models =
      answers
      |> Enum.with_index()
      |> Enum.map(fn {answer, index} -> %Answer{answer: answer, order: index + 1, specification_id: specification.id} end)

    {:ok, Enum.map(answer_models, &Repo.insert!/1)}
  end

  defp create_participation(user, run) do
    %Participation{}
    |> Participation.changeset(%{user_id: user.id, run_id: run.id})
    |> Repo.insert()
  end

  defp choose_unplaced_concept do
    concepts_yaml()
    |> Enum.filter(fn {_, v} -> v["placeless"] == true end)
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

  defp get_nearest_specification(latitude, longitude) do
    point = %Geo.Point{coordinates: {longitude, latitude}, srid: 4326}

    Specification
    |> join(:inner, [i], r in assoc(i, :region))
    |> order_by([i, r], fragment("ST_Distance(?, ?)", r.geom, ^point))
    |> limit(1)
    |> Repo.one()
  end

  def list_specifications do
    Specification |> Repo.all() |> Repo.preload(region: [parent: [parent: [:parent]]])
  end

  def list_specifications_for(user) do
    from(i in Specification)
    |> where([i], i.creator_id == ^user.id)
    |> Repo.all()
    |> Repo.preload(answers: [:reveals], region: [parent: [parent: [:parent]]])
  end

  def get_specification!(id), do: Repo.get!(Specification, id)

  def update_specification(%Specification{} = specification, attrs) do
    specification
    |> Specification.changeset(attrs)
    |> Repo.update()
  end

  def get_submission!(id),
    do:
      Submission
      |> Repo.get!(id)
      |> Repo.preload(submission_preloads())
      |> Repo.preload([:creator, run: [submissions: [:creator]]], prefix: "public")

  def create_submission(conn, %{"submission" => submission_text, "run_id" => run_id} = params) do
    current_user_id = conn.assigns[:current_user].id
    answer_id = Map.get(params, "answer_id")

    run = get_run!(run_id)

    with {:ok, _} <- validate_run_status(run),
         {:ok, _} <- validate_concept_answer(run.specification.concept, answer_id, run.specification.answers),
         {:ok, _} <- check_submission_validity(current_user_id, run, submission_text, answer_id) do
      result = insert_submission(current_user_id, run, submission_text, answer_id)

      run = get_run!(run_id)

      case result do
        {:ok, _} when not is_nil(run.winner_submission_id) ->
          broadcast_run_update(run, conn)

        _ ->
          :ok
      end

      result
    end
  end

  defp validate_run_status(run) do
    cond do
      is_nil(run.started_at) ->
        {:error, "Run has not been started"}

      run_expired?(run) ->
        {:error, "Run has expired"}

      true ->
        {:ok, run}
    end
  end

  defp validate_concept_answer(concept, answer_id, answers) do
    if concept_requires_paired_answer?(concept) and
         (is_nil(answer_id) or answer_id not in Enum.map(answers, & &1.id)) do
      {:error, "Answer does not belong to specification"}
    else
      {:ok, nil}
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

  defp check_submission_validity(current_user_id, run, submission_text, answer_id) do
    case run.specification.concept do
      "string_collector" ->
        check_for_duplicate_normalised_submission(current_user_id, run, submission_text)

      concept when concept in ["food_court_frenzy", "fill_in_the_blank", "count_the_items"] ->
        check_for_paired_answer(run, answer_id)

      concept when concept in ["orientation_memory", "cardinal_memory"] ->
        check_for_ordered_answer(run, answer_id)

      _ ->
        {:ok, nil}
    end
  end

  defp check_for_duplicate_normalised_submission(current_user_id, run, submission_text) do
    normalized_submission = normalize_string(submission_text)

    existing_submissions =
      Enum.map(Enum.filter(run.submissions, &(&1.creator_id == current_user_id)), &normalize_string(&1.submission))

    if normalized_submission in existing_submissions do
      {:error, "Submission already submitted"}
    else
      {:ok, nil}
    end
  end

  defp check_for_paired_answer(run, answer_id) do
    answer_with_submitted_id = Enum.find(run.specification.answers, fn a -> a.id == answer_id end)

    cond do
      is_nil(answer_id) ->
        {:error, "Answer is required"}

      is_nil(answer_with_submitted_id) ->
        {:error, "Unknown answer: #{answer_id}"}

      Enum.any?(run.submissions, fn s -> s.correct && s.answer_id == answer_id end) ->
        {:error, "Submission already exists for label: #{answer_with_submitted_id.label}"}

      true ->
        {:ok, nil}
    end
  end

  defp check_for_ordered_answer(run, answer_id) do
    answer_with_submitted_id = Enum.find(run.specification.answers, fn a -> a.id == answer_id end)
    latest_submission = run.submissions |> Enum.sort_by(&{&1.inserted_at, &1.answer.order}, :desc) |> List.first()

    expected_answer_order =
      cond do
        is_nil(latest_submission) -> 1
        latest_submission.correct -> latest_submission.answer.order + 1
        true -> 1
      end

    if answer_with_submitted_id.order == expected_answer_order do
      {:ok, nil}
    else
      {:error,
       "Expected submission for answer of order #{expected_answer_order}, id #{Enum.find(run.specification.answers, fn a -> a.order == expected_answer_order end).id}"}
    end
  end

  defp insert_submission(current_user_id, run, submission_text, answer_id) do
    correct = check_submission_correctness(run, submission_text, answer_id)

    attrs = %{
      "creator_id" => current_user_id,
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

  def get_run_progress(run, current_user_id) do
    correct_submissions =
      if run.specification.concept in ["orientation_memory", "cardinal_memory"] do
        latest_submission = run.submissions |> Enum.sort_by(&{&1.inserted_at, &1.answer.order}, :desc) |> List.first()

        if is_nil(latest_submission) or not latest_submission.correct do
          0
        else
          latest_submission.answer.order
        end
      else
        run.submissions
        |> Enum.uniq_by(& &1.submission)
        |> Enum.count(& &1.correct)
      end

    total_answers = length(run.specification.answers)

    competitors = get_competitors_progress(run, current_user_id)

    %{
      correct_submissions: correct_submissions,
      total_answers: total_answers,
      complete: run.winner_submission_id != nil,
      competitors: competitors
    }
  end

  defp get_competitors_progress(run, current_user_id) do
    run.participations
    |> Enum.reject(&(&1.user_id == current_user_id))
    |> Map.new(fn participation ->
      user = Repo.get!(RegistrationsWeb.User, participation.user_id)
      correct_submissions = Enum.count(run.submissions, &(&1.creator_id == user.id && &1.correct))
      {user.email, %{correct_submissions: correct_submissions, total_answers: length(run.specification.answers)}}
    end)
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

  def start_run(current_user, %Run{} = run) do
    run_has_current_user_participation = run.participations |> Enum.map(& &1.user_id) |> Enum.member?(current_user.id)

    if run_has_current_user_participation do
      case run.started_at do
        nil ->
          run
          |> Run.changeset(%{started_at: DateTime.utc_now()})
          |> Repo.update()

        _ ->
          {:error, "Run already started"}
      end
    else
      {:error, "User is not a participant in this run"}
    end
  end

  defp run_preloads do
    [
      participations: [run: [:participations, specification: [answers: [:reveals]], submissions: [answer: [:reveals]]]],
      submissions: [answer: [:reveals]],
      specification: [answers: [:reveals], region: [parent: [parent: [:parent]]]]
    ]
  end

  defp submission_preloads do
    [answer: [:reveals], run: [:participations, specification: [answers: [:reveals]], submissions: [answer: [:reveals]]]]
  end

  def get_participation!(id),
    do: Participation |> Repo.get!(id) |> Repo.preload(run: run_preloads()) |> Repo.preload(:user, prefix: "public")

  def update_participation(%Participation{} = participation, attrs, conn) do
    result =
      participation
      |> Participation.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_participation} ->
        broadcast_participation_update(updated_participation, conn)
        check_and_start_run(updated_participation.run_id, conn)
        result

      error ->
        error
    end
  end

  defp broadcast_participation_update(participation, conn) do
    run = get_run!(participation.run_id)
    broadcast_run_update(run, conn)
  end

  defp broadcast_run_update(run, conn) do
    payload = RegistrationsWeb.RunView.render("show.json", %{conn: conn, data: run})
    RegistrationsWeb.Endpoint.broadcast("run:#{run.id}", "run_update", payload)
  end

  defp check_and_start_run(run_id, conn) do
    run = run_id |> get_run!() |> Repo.preload(:participations)

    if all_participants_ready?(run) do
      start_run_new(run, conn)
    end
  end

  defp all_participants_ready?(run) do
    Enum.all?(run.participations, &(&1.ready_at != nil))
  end

  defp start_run_new(run, conn) do
    start_time = DateTime.add(DateTime.utc_now(), 5, :second)
    {:ok, started_run} = update_run(run, %{started_at: start_time})
    started_run = Repo.preload(started_run, run_preloads())

    payload = RegistrationsWeb.RunView.render("show.json", %{conn: conn, data: started_run})

    RegistrationsWeb.Endpoint.broadcast("run:#{run.id}", "run_update", payload)
  end

  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  def create_reveal(user, answer_id \\ nil, run_id \\ nil) do
    case answer_id do
      nil ->
        unrevealed_answers_query =
          from(a in Answer,
            where: not is_nil(a.hint),
            where:
              a.id not in subquery(
                from(r in Reveal,
                  where: r.user_id == ^user.id and r.run_id == ^run_id,
                  select: r.answer_id
                )
              ),
            where: a.specification_id in subquery(from(r in Run, where: r.id == ^run_id, select: r.specification_id))
          )

        case Repo.one(from(a in unrevealed_answers_query, order_by: fragment("RANDOM()"), limit: 1)) do
          nil -> {:error, :no_reveals_available}
          answer -> do_create_reveal(user, answer, run_id)
        end

      id ->
        answer = Repo.get(Answer, id)

        cond do
          is_nil(answer.hint) ->
            {:error, :hint_not_available}

          Repo.exists?(from(r in Reveal, where: r.answer_id == ^id and r.user_id == ^user.id and r.run_id == ^run_id)) ->
            {:error, :already_revealed}

          true ->
            do_create_reveal(user, answer, run_id)
        end
    end
  end

  defp do_create_reveal(user, answer, run_id) do
    result =
      %Reveal{}
      |> Reveal.changeset(%{user_id: user.id, answer_id: answer.id, run_id: run_id})
      |> Repo.insert()

    case result do
      {:ok, reveal} ->
        {:ok, Repo.preload(reveal, answer: [:reveals])}

      error ->
        error
    end
  end

  def get_reveal!(id) do
    Reveal
    |> Repo.get!(id)
    |> Repo.preload([:answer, :user])
  end
end
