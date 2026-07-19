defmodule RegistrationsWeb.Landgrab.AttemptController do
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias Registrations.Landgrab.PlayerStrings

  # Answering a relic is a gameplay action — refused before the event
  # starts and again once the game is over (stakes can still be scanned
  # and relics viewed after the end, just not captured).
  plug(RegistrationsWeb.Plugs.RequireEventStarted when action in [:create])
  plug(RegistrationsWeb.Plugs.RequireGameNotEnded when action in [:create])

  def create(conn, %{"puzzlet_id" => puzzlet_id} = params) do
    user = Pow.Plug.current_user(conn)
    answer = params["answer"] || ""

    if is_nil(user.team_id) do
      conn
      |> put_status(:forbidden)
      |> json(%{error: %{code: "no_team", detail: PlayerStrings.no_team_detail()}})
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
            detail: PlayerStrings.own_creation_detail()
          }
        })

      {:error, :already_owner} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: %{code: "already_owner", detail: PlayerStrings.already_owner_detail()}})

      {:error, :outside_zone} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "outside_zone",
            detail: PlayerStrings.outside_zone_detail()
          }
        })

      {:error, :locked_out} ->
        conn
        |> put_status(:locked)
        |> json(%{error: %{code: "locked_out", detail: PlayerStrings.locked_out_detail()}})

      {:error, :not_active} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "not_active",
            detail: PlayerStrings.not_active_detail()
          }
        })

      {:error, :withdrawn} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{
            code: "withdrawn",
            detail: PlayerStrings.withdrawn_detail()
          }
        })

      {:error, :already_captured} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: %{code: "already_captured", detail: PlayerStrings.already_captured_detail()}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", %{changeset: changeset})
    end
  end

  defp render_capture(%{capture: capture}, pole) do
    pole_locked = Registrations.Landgrab.pole_locked?(pole)

    # The capturing team's stable colour index, so the app can flood the
    # capture celebration in the team's own colour — authoritative even on a
    # team's first capture, when the map hasn't seen that colour yet.
    color_index =
      Registrations.Landgrab.team_style_index()
      |> Map.get(capture.team_id, %{})
      |> Map.get(:color_index)

    %{
      correct: true,
      captured: true,
      capture: %{id: capture.id, team_id: capture.team_id, puzzlet_id: capture.puzzlet_id},
      pole: %{
        id: pole.id,
        locked: pole_locked,
        current_owner_team_id: capture.team_id,
        current_owner_color_index: color_index
      }
    }
  end
end
