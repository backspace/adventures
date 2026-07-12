defmodule Registrations.Landgrab.Push do
  @moduledoc """
  Fans a team-directed notification out to the push tokens of the
  team's members. Fire-and-forget: called from the notification
  funnel in `Registrations.Landgrab`, which already guards against
  side effects failing a scan or capture. Tokens FCM reports as gone
  are deleted so we stop pushing to uninstalled apps.
  """
  import Ecto.Query

  alias Pigeon.FCM.Notification
  alias Registrations.Landgrab.DeviceToken
  alias Registrations.Repo

  require Logger

  @doc """
  True when the FCM dispatcher is running (i.e. the Firebase
  service-account credentials were present at boot).
  """
  def enabled? do
    Process.whereis(Registrations.FCM) != nil
  end

  @doc """
  Push `title`/`body` to every device registered by a member of
  `team_id`. `data` values must be strings (FCM requirement).
  """
  def push_to_team(team_id, title, body, data \\ %{}) do
    if enabled?() do
      tokens = team_tokens(team_id)

      Enum.each(tokens, fn token ->
        {:token, token}
        |> Notification.new(%{"title" => title, "body" => body}, data)
        |> Registrations.FCM.push(on_response: &handle_response/1)
      end)
    end

    :ok
  end

  defp team_tokens(team_id) do
    DeviceToken
    |> join(:inner, [t], u in RegistrationsWeb.User, on: u.id == t.user_id)
    |> where([t, u], u.team_id == ^team_id)
    |> select([t], t.token)
    |> Repo.all()
  end

  # FCM says this token no longer corresponds to an installed app —
  # remove it so future pushes don't retry a dead device.
  defp handle_response(%Notification{response: response, target: {:token, token}})
       when response in [:unregistered, :not_found] do
    Repo.delete_all(where(DeviceToken, token: ^token))
    :ok
  end

  defp handle_response(%Notification{response: :success}), do: :ok

  defp handle_response(%Notification{response: response, error: error}) do
    Logger.warning("push failed: #{inspect(response)} #{inspect(error)}")
    :ok
  end
end
