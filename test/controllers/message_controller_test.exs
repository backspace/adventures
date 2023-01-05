defmodule AdventureRegistrationsWeb.MessageControllerTest do
  use AdventureRegistrationsWeb.ConnCase

  # alias AdventureRegistrationsWeb.Message
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
end
