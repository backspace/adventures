defmodule RegistrationsWeb.RevealController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  plug(JSONAPI.QueryParser, view: RegistrationsWeb.RevealView)

  action_fallback(RegistrationsWeb.FallbackController)

  def create(conn, params) do
    case Waydowntown.create_reveal(conn.assigns.current_user, params["answer_id"]) do
      {:ok, reveal} ->
        conn
        |> put_status(:created)
        |> render("show.json", %{data: reveal, conn: conn, params: params})

      {:error, :no_reveals_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: "No reveals available"}]})

      {:error, :already_revealed} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: "Answer already revealed"}]})

      {:error, :hint_not_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: "Hint not available for this answer"}]})
    end
  end
end
