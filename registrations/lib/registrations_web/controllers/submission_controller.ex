defmodule RegistrationsWeb.SubmissionController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Submission

  plug(JSONAPI.QueryParser, view: RegistrationsWeb.SubmissionView)

  action_fallback(RegistrationsWeb.FallbackController)

  def create(conn, params) do
    case Waydowntown.create_submission(params) do
      {:ok, %Submission{} = submission} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.submission_path(conn, :show, submission))
        |> render("show.json", %{submission: submission, conn: conn, params: params})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", %{changeset: changeset})

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: message}]})
    end
  end

  def show(conn, %{"id" => id} = params) do
    submission = Waydowntown.get_submission!(id)
    render(conn, "show.json", %{submission: submission, conn: conn, params: params})
  end
end
