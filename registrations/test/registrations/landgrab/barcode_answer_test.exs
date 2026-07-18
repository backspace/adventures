defmodule Registrations.Landgrab.BarcodeAnswerTest do
  use Registrations.DataCase

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Repo

  setup do
    team = insert(:team)
    user = insert(:user, team_id: team.id)
    %{team: team, user: user}
  end

  defp barcode_puzzlet(answer) do
    pole = insert(:pole)
    puzzlet =
      insert(:puzzlet, pole: pole, status: :validated, answer_type: :barcode, answer: answer)

    {pole, puzzlet}
  end

  defp attempt(puzzlet, team, user, given) do
    Landgrab.record_attempt(Repo.get(Puzzlet, puzzlet.id), team.id, user.id, given)
  end

  test "matches when a scanner drops the UPC-A leading zero", %{team: team, user: user} do
    {pole, puzzlet} = barcode_puzzlet("012345678905")
    # Answering requires an active row — scan the pole first.
    {:ok, _} = Landgrab.scan_payload(pole.barcode, team.id, user.id)

    # Android/ML Kit returns the code without the leading zero that the
    # stored (iOS/EAN-13-style) answer carries; it should still match.
    assert {:ok, %{result: :captured}} = attempt(puzzlet, team, user, "12345678905")
  end

  test "still rejects a genuinely different numeric code", %{team: team, user: user} do
    {pole, puzzlet} = barcode_puzzlet("012345678905")
    {:ok, _} = Landgrab.scan_payload(pole.barcode, team.id, user.id)

    assert {:ok, %{result: :incorrect}} = attempt(puzzlet, team, user, "99999999999")
  end
end
