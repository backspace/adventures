defmodule RegistrationsWeb.PolesChannelTest do
  use RegistrationsWeb.ChannelCase

  import Registrations.Factory

  alias Registrations.Poles
  alias RegistrationsWeb.PolesChannel
  alias RegistrationsWeb.UserSocket

  setup do
    subscriber = insert(:user)
    {:ok, _, socket} =
      UserSocket
      |> socket("user_socket", %{user_id: subscriber.id})
      |> subscribe_and_join(PolesChannel, "poles:map")

    %{socket: socket, subscriber: subscriber}
  end

  test "broadcasts pole_updated when a team captures a puzzlet" do
    team = insert(:team)
    actor = insert(:user, team: team)
    pole = insert(:pole)
    puzzlet = insert(:puzzlet, pole: pole, answer: "right")

    {:ok, %{result: :captured}} =
      Poles.record_attempt(puzzlet, team.id, actor.id, "right")

    assert_broadcast "pole_updated", %{
      id: pole_id,
      current_owner_team_id: owner_id,
      locked: locked
    }

    assert pole_id == pole.id
    assert owner_id == team.id
    assert locked == true
  end

  test "does not broadcast on a wrong attempt" do
    team = insert(:team)
    actor = insert(:user, team: team)
    pole = insert(:pole)
    puzzlet = insert(:puzzlet, pole: pole, answer: "right")

    {:ok, %{result: :incorrect}} =
      Poles.record_attempt(puzzlet, team.id, actor.id, "wrong")

    refute_broadcast "pole_updated", %{}
  end
end
