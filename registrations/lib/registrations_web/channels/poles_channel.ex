defmodule RegistrationsWeb.PolesChannel do
  @moduledoc false
  use RegistrationsWeb, :channel

  @impl true
  def join("poles:map", _payload, socket) do
    {:ok, socket}
  end
end
