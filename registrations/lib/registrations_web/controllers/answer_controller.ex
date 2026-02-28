defmodule RegistrationsWeb.AnswerController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias Registrations.Waydowntown.Answer
  alias RegistrationsWeb.Owner.AnswerView

  action_fallback(RegistrationsWeb.FallbackController)

  def create(conn, %{"specification_id" => specification_id} = params) do
    user = Pow.Plug.current_user(conn)
    specification = Waydowntown.get_specification!(specification_id)

    if specification.creator_id == user.id do
      order = Waydowntown.get_next_answer_order(specification_id)
      params = Map.put(params, "order", order)

      with {:ok, %Answer{} = answer} <- Waydowntown.create_answer(params) do
        answer = Waydowntown.get_answer!(answer.id)

        conn
        |> put_status(:created)
        |> put_view(AnswerView)
        |> render("show.json", %{data: answer, conn: conn})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: [%{detail: "Unauthorized"}]})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)
    answer = Waydowntown.get_answer!(id)

    if answer.specification.creator_id == user.id do
      with {:ok, %Answer{} = updated_answer} <- Waydowntown.update_answer(answer, params) do
        conn
        |> put_view(AnswerView)
        |> render("show.json", %{data: updated_answer, conn: conn})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: [%{detail: "Unauthorized"}]})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)
    answer = Waydowntown.get_answer!(id)

    if answer.specification.creator_id == user.id do
      with {:ok, %Answer{}} <- Waydowntown.delete_answer(answer) do
        send_resp(conn, :no_content, "")
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: [%{detail: "Unauthorized"}]})
    end
  end
end
