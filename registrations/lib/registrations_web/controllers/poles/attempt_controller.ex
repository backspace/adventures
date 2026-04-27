defmodule RegistrationsWeb.Poles.AttemptController do
  use RegistrationsWeb, :controller

  alias Registrations.Poles

  def create(conn, %{"puzzlet_id" => puzzlet_id} = params) do
    user = Pow.Plug.current_user(conn)
    answer = params["answer"] || ""

    cond do
      is_nil(user.team_id) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: %{code: "no_team", detail: "User is not on a team."}})

      true ->
        case Poles.get_puzzlet(puzzlet_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: %{code: "puzzlet_not_found"}})

          puzzlet ->
            handle_attempt(conn, puzzlet, user, answer)
        end
    end
  end

  defp handle_attempt(conn, puzzlet, user, answer) do
    case Poles.record_attempt(puzzlet, user.team_id, user.id, answer) do
      {:ok, %{result: :captured} = outcome} ->
        pole = Poles.get_pole!(puzzlet.pole_id)
        json(conn, render_capture(outcome, pole))

      {:ok, %{result: :incorrect, attempts_remaining: remaining}} ->
        json(conn, %{correct: false, attempts_remaining: remaining})

      {:error, :locked_out} ->
        conn
        |> put_status(:locked)
        |> json(%{error: %{code: "locked_out", detail: "Too many wrong attempts on this puzzlet."}})

      {:error, :already_captured} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: %{code: "already_captured", detail: "Another team captured this puzzlet first."}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", %{changeset: changeset})
    end
  end

  defp render_capture(%{capture: capture}, pole) do
    pole_locked = Registrations.Poles.pole_locked?(pole)

    %{
      correct: true,
      captured: true,
      capture: %{id: capture.id, team_id: capture.team_id, puzzlet_id: capture.puzzlet_id},
      pole: %{id: pole.id, locked: pole_locked, current_owner_team_id: capture.team_id}
    }
  end
end
