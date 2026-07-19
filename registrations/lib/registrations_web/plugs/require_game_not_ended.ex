defmodule RegistrationsWeb.Plugs.RequireGameNotEnded do
  @moduledoc """
  Refuses relic answers once the game is over — the endgame shrink
  window's end (`endgame_ends_at`) doubles as the end of the game.
  Scanning stakes and viewing relics stay open afterwards; only
  capturing is closed. An event with no endgame configured never
  ends, so this is a no-op until one is set up.
  """
  import Plug.Conn

  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events
  alias Registrations.Landgrab.PlayerStrings

  def init(opts), do: opts

  def call(conn, _opts) do
    if Event.ended?(Events.current(), DateTime.utc_now()) do
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{
        error: %{code: "game_over", detail: PlayerStrings.game_over_detail()}
      })
      |> halt()
    else
      conn
    end
  end
end
