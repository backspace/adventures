defmodule RegistrationsWeb.Poles.TestPlayController do
  @moduledoc """
  Test-play API. Mirrors the player-side gameplay endpoints but writes to
  scoped (test-session-tagged) attempts and captures, leaving the real
  game state untouched.

  Routed at `/poles/test-play`, requires validator OR validation_supervisor
  role via the `:poles_tester` pipeline.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Poles
  alias Registrations.Poles.Scope

  # ─── Sessions ────────────────────────────────────────────────────────

  def create_session(conn, params) do
    user = Pow.Plug.current_user(conn)

    case Poles.create_test_session(user, %{name: params["name"]}) do
      {:ok, session} ->
        conn |> put_status(:created) |> json(render_session(session))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(RegistrationsWeb.ChangesetView)
        |> render("error.json", %{changeset: changeset})
    end
  end

  def list_sessions(conn, _params) do
    user = Pow.Plug.current_user(conn)
    sessions = Poles.list_test_sessions_for_user(user)
    json(conn, %{sessions: Enum.map(sessions, &render_session/1)})
  end

  def end_session(conn, %{"id" => id}) do
    user = Pow.Plug.current_user(conn)

    case Poles.get_test_session(id) do
      nil ->
        not_found(conn)

      %{creator_id: cid} when cid != user.id ->
        forbidden(conn, "You can only end your own test sessions.")

      session ->
        {:ok, ended} = Poles.end_test_session(session)
        json(conn, render_session(ended))
    end
  end

  # ─── Scoped gameplay ────────────────────────────────────────────────

  def list_poles(conn, %{"session_id" => session_id}) do
    case authorize_session(conn, session_id) do
      {:ok, _session} ->
        states = Poles.list_poles_with_state(Scope.test(session_id))
        json(conn, %{poles: Enum.map(states, &render_pole_state/1)})

      {:halt, conn} ->
        conn
    end
  end

  def scan_pole(conn, %{"session_id" => session_id, "barcode" => barcode}) do
    case authorize_session(conn, session_id) do
      {:halt, conn} ->
        conn

      {:ok, _session} ->
        user = Pow.Plug.current_user(conn)
        scope = Scope.test(session_id)
        do_scan_pole(conn, user, scope, barcode)
    end
  end

  defp do_scan_pole(conn, user, scope, barcode) do
    case Poles.scan_payload(barcode, user.team_id, user.id, scope) do
      {:ok, state} ->
        json(conn, %{
          pole: render_pole_state(state),
          active_puzzlet:
            render_puzzlet(
              state.active_puzzlet,
              state.attempts_remaining,
              state.previous_wrong_answers
            )
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "pole_not_found", detail: "No pole with that barcode."}})

      {:error, :already_owner, pole} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: %{code: "already_owner", detail: "Already captured in this test session."},
          pole: render_pole_state(Poles.pole_with_state(pole, scope))
        })

      {:error, :team_locked_out, pole} ->
        conn
        |> put_status(:locked)
        |> json(%{
          error: %{
            code: "team_locked_out",
            detail: "You've used all guesses on this puzzlet in this test session."
          },
          pole: render_pole_state(Poles.pole_with_state(pole, scope))
        })
    end
  end

  def submit_attempt(conn, %{
        "session_id" => session_id,
        "puzzlet_id" => puzzlet_id,
        "answer" => answer
      }) do
    case authorize_session(conn, session_id) do
      {:halt, conn} ->
        conn

      {:ok, _session} ->
        user = Pow.Plug.current_user(conn)
        scope = Scope.test(session_id)
        do_submit_attempt(conn, user, scope, puzzlet_id, answer)
    end
  end

  defp do_submit_attempt(conn, user, scope, puzzlet_id, answer) do
    case Poles.get_puzzlet(puzzlet_id) do
      nil ->
        not_found(conn)

      puzzlet ->
        # Pass nil for team_id; in test scope, scope is the identity.
        case Poles.record_attempt(puzzlet, nil, user.id, answer, scope) do
          {:ok, %{result: :captured} = result} ->
            json(conn, %{outcome: "correct", attempt: render_attempt(result.attempt)})

          {:ok, %{result: :incorrect} = result} ->
            json(conn, %{
              outcome: "incorrect",
              attempts_remaining: result.attempts_remaining,
              previous_wrong_answers: Poles.team_wrong_answers(puzzlet, nil, scope)
            })

          {:error, :already_owner} ->
            conn |> put_status(:conflict) |> json(%{error: %{code: "already_owner"}})

          {:error, :locked_out} ->
            conn |> put_status(:locked) |> json(%{error: %{code: "locked_out"}})

          {:error, :already_captured} ->
            conn |> put_status(:conflict) |> json(%{error: %{code: "already_captured"}})
        end
    end
  end

  # ─── Helpers ─────────────────────────────────────────────────────────

  defp authorize_session(conn, session_id) do
    user = Pow.Plug.current_user(conn)

    case Poles.get_test_session(session_id) do
      nil ->
        {:halt, not_found(conn)}

      %{creator_id: cid} when cid != user.id ->
        {:halt, forbidden(conn, "Not your session.")}

      session ->
        {:ok, session}
    end
  end

  defp render_session(session) do
    %{
      id: session.id,
      name: session.name,
      ended_at: session.ended_at,
      inserted_at: session.inserted_at
    }
  end

  defp render_pole_state(%{pole: pole, current_owner_team_id: owner, locked?: locked}) do
    %{
      id: pole.id,
      barcode: pole.barcode,
      label: pole.label,
      latitude: pole.latitude,
      longitude: pole.longitude,
      current_owner_team_id: owner,
      locked: locked
    }
  end

  defp render_puzzlet(nil, _, _), do: nil

  defp render_puzzlet(puzzlet, attempts_remaining, previous_wrong_answers) do
    %{
      id: puzzlet.id,
      instructions: puzzlet.instructions,
      difficulty: puzzlet.difficulty,
      answer_type: puzzlet.answer_type,
      warning: puzzlet.warning,
      attempts_remaining: attempts_remaining,
      previous_wrong_answers: previous_wrong_answers
    }
  end

  defp render_attempt(attempt) do
    %{id: attempt.id, correct: attempt.correct, answer_given: attempt.answer_given}
  end

  defp not_found(conn) do
    conn |> put_status(:not_found) |> json(%{error: %{code: "not_found"}})
  end

  defp forbidden(conn, detail) do
    conn |> put_status(:forbidden) |> json(%{error: %{code: "forbidden", detail: detail}})
  end
end
