defmodule RegistrationsWeb.RunChannel do
  @moduledoc false
  use RegistrationsWeb, :channel

  alias Registrations.Waydowntown

  @impl true
  def join("run:" <> run_id, _payload, socket) do
    user_id = socket.assigns.user_id

    case Waydowntown.get_run!(run_id) do
      %{participations: participations} = run ->
        if Enum.any?(participations, &(&1.user_id == user_id)) do
          {:ok, assign(socket, :run_id, run.id)}
        else
          {:error, %{reason: "unauthorized"}}
        end

      nil ->
        {:error, %{reason: "not found"}}
    end
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
