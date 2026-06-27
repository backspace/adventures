defmodule RegistrationsWeb.Landgrab.AttemptController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab

  def create(conn, %{"puzzlet_id" => puzzlet_id} = params) do
    user = Pow.Plug.current_user(conn)
    answer = params["answer"] || ""

    if is_nil(user.team_id) do
      conn
      |> put_status(:forbidden)
      |> json(%{error: %{code: "no_team", detail: "User is not on a team."}})
    else
      case Landgrab.get_puzzlet(puzzlet_id) do
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
    case Landgrab.record_attempt(puzzlet, user.team_id, user.id, answer) do
      {:ok, %{result: :captured} = outcome} ->
        pole = Landgrab.get_pole!(puzzlet.pole_id)
        json(conn, render_capture(outcome, pole))

      {:ok, %{result: :incorrect, attempts_remaining: remaining}} ->
        wrong_answers = Landgrab.team_wrong_answers(puzzlet, user.team_id)

        json(conn, %{
          correct: false,
          attempts_remaining: remaining,
          previous_wrong_answers: wrong_answers
        })

      {:error, :own_creation} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "own_creation",
            detail: "You created this puzzlet or pole — you can't capture it."
          }
        })

      {:error, :already_owner} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: %{code: "already_owner", detail: "Your team already owns this pole."}})

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
    pole_locked = Registrations.Landgrab.pole_locked?(pole)

    %{
      correct: true,
      captured: true,
      capture: %{id: capture.id, team_id: capture.team_id, puzzlet_id: capture.puzzlet_id},
      pole: %{id: pole.id, locked: pole_locked, current_owner_team_id: capture.team_id}
    }
  end
end
