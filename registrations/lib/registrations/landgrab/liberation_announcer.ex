defmodule Registrations.Landgrab.LiberationAnnouncer do
  @moduledoc """
  Minute-by-minute poll that trickles liberation invitations out to teams as
  their rollout slots pass (see `Landgrab.maybe_invite_liberation_teams/1`).
  Polling (rather than scheduling exact instants) means supervisor edits to
  the rollout window are picked up without cache-invalidation choreography —
  worst case an invitation lands a minute late. Disabled in tests via the
  `:start_liberation_announcer` config flag.
  """
  use GenServer

  require Logger

  @poll_interval :timer.minutes(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule()
    {:ok, nil}
  end

  @impl true
  def handle_info(:poll, state) do
    case Registrations.Landgrab.maybe_invite_liberation_teams() do
      {:invited, team_count} ->
        Logger.info("liberation invitations sent to #{team_count} teams")

      :noop ->
        :ok
    end

    # Bedab's one-shot "accounting" broadcast, scheduled between the invite
    # rollout and the endgame. Same minute poll; one-shot via its sent stamp.
    case Registrations.Landgrab.maybe_send_accounting() do
      {:sent, team_count} ->
        Logger.info("accounting message sent to #{team_count} teams")

      :noop ->
        :ok
    end

    schedule()
    {:noreply, state}
  rescue
    error ->
      # Keep polling through transient failures (e.g. DB hiccup).
      Logger.error("liberation announcer poll failed: #{Exception.message(error)}")
      schedule()
      {:noreply, state}
  end

  defp schedule do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
