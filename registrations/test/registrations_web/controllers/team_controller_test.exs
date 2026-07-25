defmodule RegistrationsWeb.TeamControllerTest do
  @moduledoc """
  Headless coverage of the admin team-member management (add via the dropdown,
  remove) that the Wallaby test in `test/integration/admin_test.exs` drives
  through the browser — kept here too so the server wiring is verified without
  a browser driver.
  """
  use RegistrationsWeb.ConnCase

  alias RegistrationsWeb.{Team, User}

  setup %{conn: conn} do
    # The site layout renders adventure-specific copy, so an adventure must be
    # configured for the edit page to render.
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :adventure,
      "clandestine-rendezvous"
    )

    admin = insert(:octavia, admin: true)
    %{conn: assign(conn, :current_user, admin)}
  end

  test "edit page lists members and a grouped add dropdown", %{conn: conn} do
    team = insert(:team, name: "Alpha", risk_aversion: 2)
    insert(:user, email: "member@example.com", team_id: team.id)
    insert(:user, email: "free@example.com")

    other = insert(:team, name: "Beta", risk_aversion: 1)
    insert(:user, email: "elsewhere@example.com", team_id: other.id)

    html = conn |> get("/teams/#{team.id}/edit") |> html_response(200)

    # Current member shown in the roster.
    assert html =~ "member@example.com"
    # Dropdown offers a teamless person and a person on another team, grouped.
    assert html =~ "add-member-select"
    assert html =~ "No team"
    assert html =~ "On another team"
    assert html =~ "free@example.com"
    assert html =~ "elsewhere@example.com"
  end

  test "add_member attaches the selected user by id", %{conn: conn} do
    team = insert(:team, name: "Alpha", risk_aversion: 2)
    outsider = insert(:user, email: "outsider@example.com")

    post(conn, "/teams/#{team.id}/members", %{"member" => %{"user_id" => outsider.id}})

    assert Repo.get(User, outsider.id).team_id == team.id
  end

  test "add_member moves a user off their previous team", %{conn: conn} do
    old = insert(:team, name: "Old", risk_aversion: 1)
    new = insert(:team, name: "New", risk_aversion: 2)
    user = insert(:user, email: "mover@example.com", team_id: old.id)

    post(conn, "/teams/#{new.id}/members", %{"member" => %{"user_id" => user.id}})

    assert Repo.get(User, user.id).team_id == new.id
  end

  test "add_member with no selection flashes an error and changes nothing", %{conn: conn} do
    team = insert(:team, name: "Alpha", risk_aversion: 2)

    result = post(conn, "/teams/#{team.id}/members", %{"member" => %{"user_id" => ""}})

    assert Phoenix.Controller.get_flash(result, :error) =~ "Choose a person"
  end

  test "remove_member detaches a user, leaving the account teamless", %{conn: conn} do
    team = insert(:team, name: "Alpha", risk_aversion: 2)
    member = insert(:user, email: "member@example.com", team_id: team.id)

    delete(conn, "/teams/#{team.id}/members/#{member.id}")

    assert Repo.get(User, member.id).team_id == nil
    # The account itself survives.
    assert Repo.get(Team, team.id)
  end

  test "member management requires an admin", %{conn: conn} do
    team = insert(:team, name: "Alpha", risk_aversion: 2)
    member = insert(:user, email: "member@example.com", team_id: team.id)

    # A non-admin is bounced by the Admin plug (redirect to "/").
    result =
      conn
      |> assign(:current_user, insert(:user))
      |> delete("/teams/#{team.id}/members/#{member.id}")

    assert redirected_to(result) == "/"
    assert Repo.get(User, member.id).team_id == team.id
  end

  describe "cards" do
    test "hides teams that already have members by default", %{conn: conn} do
      empty = insert(:team, name: "EmptyOne", join_code: "EMPTY1", risk_aversion: 1)
      full = insert(:team, name: "HasMembers", join_code: "FULL01", risk_aversion: 2)
      insert(:user, email: "m@example.com", team_id: full.id)

      html = conn |> get("/teams/cards") |> html_response(200)

      assert html =~ empty.name
      refute html =~ full.name
    end

    test "shows every team when hide_with_members=false", %{conn: conn} do
      empty = insert(:team, name: "EmptyOne", join_code: "EMPTY1", risk_aversion: 1)
      full = insert(:team, name: "HasMembers", join_code: "FULL01", risk_aversion: 2)
      insert(:user, email: "m@example.com", team_id: full.id)

      html = conn |> get("/teams/cards?hide_with_members=false") |> html_response(200)

      assert html =~ empty.name
      assert html =~ full.name
    end
  end
end
