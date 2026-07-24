defmodule RegistrationsWeb.Landgrab.HomepageNoteTest do
  use RegistrationsWeb.ConnCase
  use Registrations.SetAdventure, adventure: "landgrab"

  alias Registrations.Landgrab.Event
  alias Registrations.Repo

  defp insert_event(attrs) do
    %Event{}
    |> Event.changeset(Map.merge(%{name: "LANDGRAB"}, attrs))
    |> Repo.insert!()
  end

  test "the event's homepage HTML renders raw, below the Sabuk line", %{conn: conn} do
    insert_event(%{homepage_html: ~s(<strong data-test-note>Bedab returns</strong>)})

    body = get(conn, "/") |> html_response(200)

    # Rendered as markup, not escaped.
    assert body =~ ~s(<strong data-test-note>Bedab returns</strong>)
    refute body =~ "&lt;strong data-test-note&gt;"

    # Sits after the Sabuk storyline line.
    assert :binary.match(body, "Visiting scholar Sabuk") |> elem(0) <
             :binary.match(body, "data-test-note") |> elem(0)
  end

  test "nothing extra renders when the field is blank", %{conn: conn} do
    insert_event(%{homepage_html: nil})

    body = get(conn, "/") |> html_response(200)

    assert body =~ "Visiting scholar Sabuk"
    refute body =~ "landgrab-homepage-note"
  end
end
