defmodule RegistrationsWeb.Landgrab.BathroomsTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts
  alias Registrations.Landgrab.Bathrooms

  defp authed_conn(%{conn: conn}, %{} = user) do
    auth_conn =
      post(build_conn(), Routes.api_session_path(build_conn(), :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    token = json_response(auth_conn, 200)["data"]["access_token"]

    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", token)
  end

  defp unique_email(prefix), do: "#{prefix}#{System.unique_integer([:positive])}@example.com"

  describe "anyone authenticated" do
    setup ctx do
      user = insert(:user, email: unique_email("any"))
      %{conn: authed_conn(ctx, user), user: user}
    end

    test "lists bathrooms but cannot create one", %{conn: conn} do
      conn |> get("/landgrab/bathrooms") |> json_response(200)
      body = conn |> post("/landgrab/bathrooms", %{"latitude" => 49.89, "longitude" => -97.13}) |> json_response(403)
      assert body["error"]["code"] == "forbidden"
    end
  end

  describe "with the author role" do
    setup ctx do
      author = insert(:user, email: unique_email("author"))
      Accounts.assign_role(author.id, "author")
      %{conn: authed_conn(ctx, author), author: author}
    end

    test "creates and lists a bathroom", %{conn: conn} do
      body =
        conn
        |> post("/landgrab/bathrooms", %{
          "name" => "Main floor bathroom",
          "latitude" => 49.89,
          "longitude" => -97.13,
          "accessibility_tags" => ["stairs"]
        })
        |> json_response(201)

      assert body["name"] == "Main floor bathroom"
      assert "stairs" in body["accessibility_tags"]

      list = conn |> get("/landgrab/bathrooms") |> json_response(200)
      assert Enum.any?(list["bathrooms"], &(&1["id"] == body["id"]))
    end

    test "creator can update their own bathroom", %{conn: conn, author: author} do
      {:ok, b} =
        Bathrooms.create_bathroom(%{
          "latitude" => 49.89,
          "longitude" => -97.13,
          "creator_id" => author.id
        })

      body =
        conn
        |> patch("/landgrab/bathrooms/#{b.id}", %{"name" => "Renamed"})
        |> json_response(200)

      assert body["name"] == "Renamed"
    end

    test "another author cannot update someone else's bathroom",
         %{conn: _conn, author: _author} = ctx do
      original = insert(:user, email: unique_email("orig"))

      {:ok, b} =
        Bathrooms.create_bathroom(%{
          "latitude" => 49.89,
          "longitude" => -97.13,
          "creator_id" => original.id
        })

      body =
        ctx.conn
        |> patch("/landgrab/bathrooms/#{b.id}", %{"name" => "Hijack"})
        |> json_response(403)

      assert body["error"]["code"] == "forbidden"
    end
  end

  describe "supervisor override" do
    setup ctx do
      supervisor = insert(:user, email: unique_email("sup"))
      Accounts.assign_role(supervisor.id, "validation_supervisor")
      %{conn: authed_conn(ctx, supervisor)}
    end

    test "supervisor can update a bathroom they didn't create", %{conn: conn} do
      original = insert(:user, email: unique_email("other"))

      {:ok, b} =
        Bathrooms.create_bathroom(%{
          "latitude" => 49.89,
          "longitude" => -97.13,
          "creator_id" => original.id
        })

      body =
        conn
        |> patch("/landgrab/bathrooms/#{b.id}", %{"name" => "Supervisor fix"})
        |> json_response(200)

      assert body["name"] == "Supervisor fix"
    end
  end
end
