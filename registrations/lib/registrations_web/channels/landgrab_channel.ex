defmodule RegistrationsWeb.LandgrabChannel do
  @moduledoc false
  use RegistrationsWeb, :channel

  @impl true
  def join("landgrab:map", _payload, socket) do
    {:ok, socket}
  end
end
