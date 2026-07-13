defmodule RegistrationsWeb.Landgrab.NotificationController do
  @moduledoc """
  The in-app notification history for the player's team. Live
  delivery is the socket broadcast + push; this is the catch-up view.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Landgrab

  def index(conn, _params) do
    case team_id(conn) do
      nil ->
        json(conn, %{notifications: [], unread: 0})

      team_id ->
        json(conn, %{
          notifications: team_id |> Landgrab.list_notifications_for_team() |> Enum.map(&render_notification/1),
          unread: Landgrab.count_unread_notifications(team_id)
        })
    end
  end

  def mark_read(conn, _params) do
    case team_id(conn) do
      nil -> json(conn, %{marked: 0})
      team_id -> json(conn, %{marked: Landgrab.mark_notifications_read(team_id)})
    end
  end

  defp team_id(conn) do
    Pow.Plug.current_user(conn).team_id
  end

  defp render_notification(notification) do
    %{
      id: notification.id,
      type: notification.type,
      recipient_team_id: notification.recipient_team_id,
      sender_team_id: notification.sender_team_id,
      body: notification.body,
      metadata: notification.metadata,
      read_at: notification.read_at,
      inserted_at: notification.inserted_at
    }
  end
end
