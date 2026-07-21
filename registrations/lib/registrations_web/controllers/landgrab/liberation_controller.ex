defmodule RegistrationsWeb.Landgrab.LiberationController do
  @moduledoc """
  Supervisor configuration for the liberation rollout: the window across which
  Bedab's invitations trickle out to teams, plus progress (invitations sent,
  answers in). PUT is full-replace — send `starts_at` (and optionally
  `rollout_ends_at`) to schedule, or nulls to cancel a rollout that hasn't
  begun. The `LiberationAnnouncer` polls every minute, so schedule edits take
  effect without a restart; invitations already sent are never recalled.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Events

  def show(conn, _params) do
    json(conn, render_status())
  end

  def update(conn, params) do
    attrs = %{
      liberation_starts_at: params["starts_at"],
      liberation_rollout_ends_at: params["rollout_ends_at"]
    }

    case Events.update(Events.current(), attrs) do
      {:ok, _updated} ->
        json(conn, render_status())

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
    end
  end

  defp render_status do
    status = Landgrab.liberation_status()

    %{
      starts_at: status.starts_at,
      rollout_ends_at: status.rollout_ends_at,
      team_count: status.team_count,
      invited: status.invited,
      accepted: status.accepted,
      declined: status.declined
    }
  end
end
