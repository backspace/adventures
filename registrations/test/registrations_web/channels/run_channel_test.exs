# FIXME is this needed? Is it covered by the participation controller tests?

defmodule RegistrationsWeb.RunChannelTest do
  use RegistrationsWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      RegistrationsWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(RegistrationsWeb.RunChannel, "run:lobby")

    %{socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to run:lobby", %{socket: socket} do
    push(socket, "shout", %{"hello" => "all"})
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end
end
