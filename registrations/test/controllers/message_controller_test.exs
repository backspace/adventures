defmodule RegistrationsWeb.MessageControllerTest do
  use RegistrationsWeb.ConnCase

  # alias RegistrationsWeb.Message
  # @valid_attrs %{
  #   content: "some content",
  #   postmarked_at: "2010-04-17",
  #   ready: true,
  #   subject: "some content"
  # }
  # @invalid_attrs %{}

  # FIXME disabled these due to inability to set session for admins…
  # generated tests, even needed?

  # setup do
  #   user = Repo.insert!(Forge.user(email: "admin@example.com", admin: true))
  #
  #   IO.puts "user? #{user.id}"
  #
  #   {:ok, conn: conn() |> get("/") |> fetch_session |> put_session(:current_user, user.id)}
  # end
  #
  # test "lists all entries on index", %{conn: conn} do
  #   conn = get conn, Routes.message_path(conn, :index)
  #   assert html_response(conn, 200) =~ "Listing messages"
  # end
  #
  # test "renders form for new resources", %{conn: conn} do
  #   conn = get conn, Routes.message_path(conn, :new)
  #   assert html_response(conn, 200) =~ "New message"
  # end
  #
  # test "creates resource and redirects when data is valid", %{conn: conn} do
  #   conn = post conn, Routes.message_path(conn, :create), message: @valid_attrs
  #   #assert redirected_to(conn) == Routes.message_path(conn, :edit, @valid_attrs)
  #   assert Repo.get_by(Message, @valid_attrs)
  # end
  #
  # test "does not create resource and renders errors when data is invalid", %{conn: conn} do
  #   conn = post conn, Routes.message_path(conn, :create), message: @invalid_attrs
  #   assert html_response(conn, 200) =~ "New message"
  # end
  #
  # test "renders page not found when id is nonexistent", %{conn: conn} do
  #   assert_raise Ecto.NoResultsError, fn ->
  #     get conn, Routes.message_path(conn, :edit, -1)
  #   end
  # end
  #
  # test "renders form for editing chosen resource", %{conn: conn} do
  #   message = Repo.insert! %Message{}
  #   conn = get conn, Routes.message_path(conn, :edit, message)
  #   assert html_response(conn, 200) =~ "Edit message"
  # end
  #
  # test "updates chosen resource and redirects when data is valid", %{conn: conn} do
  #   message = Repo.insert! %Message{}
  #   conn = put conn, Routes.message_path(conn, :update, message), message: @valid_attrs
  #   assert redirected_to(conn) == Routes.message_path(conn, :edit, message)
  #   assert Repo.get_by(Message, @valid_attrs)
  # end
  #
  # test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
  #   message = Repo.insert! %Message{}
  #   conn = put conn, Routes.message_path(conn, :update, message), message: @invalid_attrs
  #   assert html_response(conn, 200) =~ "Edit message"
  # end
  #
  # test "deletes chosen resource", %{conn: conn} do
  #   message = Repo.insert! %Message{}
  #   conn = delete conn, Routes.message_path(conn, :delete, message)
  #   assert redirected_to(conn) == Routes.message_path(conn, :index)
  #   refute Repo.get(Message, message.id)
  # end

  use Registrations.SwooshHelper

  alias RegistrationsWeb.User

  setup do
    # The email layout renders adventure-specific chrome.
    Registrations.ApplicationEnvHelpers.put_application_env_for_test(
      :registrations,
      :adventure,
      "clandestine-rendezvous"
    )

    :ok
  end

  test "send-to-me reflects the real team even when the session's team_id is stale",
       %{conn: conn} do
    team = insert(:team, name: "Zephyrs", risk_aversion: 2)
    admin = insert(:octavia, admin: true, team_id: team.id)

    message =
      insert(:message,
        subject: "Hello",
        content: "Body copy",
        show_team: true,
        ready: true,
        postmarked_at: ~D[2020-01-01]
      )

    # Simulate the Pow session cached from BEFORE the team was assigned: same
    # user id, but a stale nil team_id. The action must re-read from the DB
    # rather than trust this, or the email would say "no team assigned".
    conn = assign(conn, :current_user, %User{admin | team_id: nil})

    post(conn, "/messages/#{message.id}/send", %{"me" => "true"})

    [email] = wait_for_emails([_email])
    assert email.to == [{"", admin.email}]
    assert email.html_body =~ "Zephyrs"
    refute email.html_body =~ "no team assigned"
  end
end
