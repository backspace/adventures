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

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (run:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
