defmodule RegistrationsWeb.AnswerController do
  use RegistrationsWeb, :controller

  plug(JSONAPI.QueryParser, view: RegistrationsWeb.AnswerView)

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Answer

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, _params) do
    answers = Waydowntown.list_answers()
    render(conn, "index.json", answers: answers)
  end

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

  def update(conn, %{"id" => id, "answer" => answer_params}) do
    answer = Waydowntown.get_answer!(id)

    with {:ok, %Answer{} = answer} <- Waydowntown.update_answer(answer, answer_params) do
      render(conn, "show.json", answer: answer)
    end
  end

  def delete(conn, %{"id" => id}) do
    answer = Waydowntown.get_answer!(id)

    with {:ok, %Answer{}} <- Waydowntown.delete_answer(answer) do
      send_resp(conn, :no_content, "")
    end
  end
end
