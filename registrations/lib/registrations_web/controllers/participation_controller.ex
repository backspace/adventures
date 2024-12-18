defmodule RegistrationsWeb.ParticipationController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown

  plug(JSONAPI.QueryParser, view: RegistrationsWeb.ParticipationView)

  action_fallback RegistrationsWeb.FallbackController

  def create(conn, %{"run_id" => run_id} = params) do
    current_user = conn.assigns[:current_user]

    case Waydowntown.join_run(current_user, run_id, conn) do
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

  def update(conn, %{"id" => id, "ready" => ready} = params) do
    participation = Waydowntown.get_participation!(id)

    if conn.assigns[:current_user].id == participation.user_id do
      ready_at = if ready, do: DateTime.utc_now()

      case Waydowntown.update_participation(participation, %{ready_at: ready_at}, conn) do
        {:ok, updated_participation} ->
          render(conn, "show.json", %{data: updated_participation, conn: conn, params: params})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(RegistrationsWeb.ChangesetView)
          |> render("error.json", changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{errors: [%{detail: "Cannot update another user's participation"}]})
    end
  end
end
