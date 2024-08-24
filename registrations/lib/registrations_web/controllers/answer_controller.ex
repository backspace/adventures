defmodule RegistrationsWeb.AnswerController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Answer

  plug(JSONAPI.QueryParser, view: RegistrationsWeb.AnswerView)

  action_fallback(RegistrationsWeb.FallbackController)

  def create(conn, params) do
    case Waydowntown.create_answer(params) do
      {:ok, %Answer{} = answer} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.answer_path(conn, :show, answer))
        |> render("show.json", %{answer: answer, conn: conn, params: params})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", %{changeset: changeset})
    end
  end

  def show(conn, %{"id" => id}) do
    answer = Waydowntown.get_answer!(id)
    render(conn, "show.json", answer: answer)
  end
end
