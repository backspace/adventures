defmodule RegistrationsWeb.ParticipationController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  plug(JSONAPI.QueryParser, view: RegistrationsWeb.ParticipationView)

  action_fallback RegistrationsWeb.FallbackController

  def create(conn, %{"run_id" => run_id} = params) do
    current_user = conn.assigns[:current_user]

    case Waydowntown.join_run(current_user, run_id) do
      {:ok, participation} ->
        conn
        |> put_status(:created)
        |> render("show.json", %{data: participation, conn: conn, params: params})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", changeset: changeset)

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: [%{detail: message}]})
    end
  end
end
