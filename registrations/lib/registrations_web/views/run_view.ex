defmodule RegistrationsWeb.RunView do
  use JSONAPI.View, type: "runs"

  alias Registrations.Waydowntown
  alias RegistrationsWeb.RunView

  def fields do
    [:complete, :correct_answers, :total_answers, :description, :started_at]
  end

  def hidden(run) do
    description_inclusion =
      case run.started_at do
        nil -> [:description]
        _ -> []
      end

    answers =
      case run.specification do
        %{"concept" => "fill_in_the_blank"} -> [:correct_answers, :total_answers]
        nil -> [:complete, :correct_answers, :total_answers]
        _ -> []
      end

    description_inclusion ++ answers
  end

  def description(run, _conn) do
    run.specification.description
  end

  def complete(run, _conn) do
    Waydowntown.get_run_progress(run).complete
  end

  def correct_answers(run, _conn) do
    Waydowntown.get_run_progress(run).correct_answers
  end

  def total_answers(run, _conn) do
    Waydowntown.get_run_progress(run).total_answers
  end

  def render("index.json", %{runs: runs, conn: conn, params: params}) do
    RunView.index(runs, conn, params)
  end

  def render("show.json", %{run: run, conn: conn, params: params}) do
    RunView.show(run, conn, params)
  end

  def relationships do
    [
      specification: {RegistrationsWeb.SpecificationView, :include}
    ]
  end
end
