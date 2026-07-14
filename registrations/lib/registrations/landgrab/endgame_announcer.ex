defmodule Registrations.Landgrab.EndgameAnnouncer do
  @moduledoc """
  Minute-by-minute poll that fires the one-shot SYSTEM broadcast when
  the endgame boundary activates. Polling (rather than scheduling for
  the exact start time) means admin edits to the endgame window are
  picked up without any cache-invalidation choreography — worst case
  the announcement lands a minute late. Disabled in tests via the
  `:start_endgame_announcer` config flag.
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
    case Registrations.Landgrab.maybe_announce_endgame() do
      {:announced, team_count} ->
        Logger.info("endgame boundary announced to #{team_count} teams")

      :noop ->
        :ok
    end

    schedule()
    {:noreply, state}
  rescue
    error ->
      # Keep polling through transient failures (e.g. DB hiccup).
      Logger.error("endgame announcer poll failed: #{Exception.message(error)}")
      schedule()
      {:noreply, state}
  end

  defp schedule do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
