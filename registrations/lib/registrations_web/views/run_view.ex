defmodule RegistrationsWeb.RunView do
  use JSONAPI.View, type: "runs"

  alias Registrations.Waydowntown

  def fields do
    [:complete, :correct_submissions, :total_answers, :task_description, :started_at, :competitors, :winner_submission_id]
  end

  def hidden(run) do
    description_inclusion =
      case run.started_at do
        nil -> [:task_description]
        _ -> []
      end

    answers =
      case run.specification do
        %{"concept" => "fill_in_the_blank"} -> [:correct_submissions, :total_answers]
        nil -> [:complete, :correct_submissions, :total_answers]
        _ -> []
      end

    description_inclusion ++ answers
  end

  def task_description(run, _conn) do
    run.specification.task_description
  end

  def complete(run, conn) do
    Waydowntown.get_run_progress(run, conn.assigns.current_user.id).complete
  end

  @spec correct_submissions(any(), any()) :: any()
  def correct_submissions(run, conn) do
    Waydowntown.get_run_progress(run, conn.assigns.current_user.id).correct_submissions
  end

  def total_answers(run, conn) do
    Waydowntown.get_run_progress(run, conn.assigns.current_user.id).total_answers
  end

  def competitors(run, conn) do
    Waydowntown.get_run_progress(run, conn.assigns.current_user.id).competitors
  end

  def relationships do
    [
      participations: {RegistrationsWeb.ParticipationView, :include},
      specification: {RegistrationsWeb.SpecificationView, :include},
      submissions: {RegistrationsWeb.SubmissionView, :include}
    ]
  end
end
