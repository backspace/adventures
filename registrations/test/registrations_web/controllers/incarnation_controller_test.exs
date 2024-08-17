defmodule RegistrationsWeb.IncarnationControllerTest do
  use RegistrationsWeb.ConnCase

  import Registrations.WaydowntownFixtures

  alias Registrations.Waydowntown.Incarnation

  @create_attrs %{
    answer: "some answer",
    answers: [],
    concept: "some concept",
    mask: "some mask"
  }
  @update_attrs %{
    answer: "some updated answer",
    answers: [],
    concept: "some updated concept",
    mask: "some updated mask"
  }
  @invalid_attrs %{answer: nil, answers: nil, concept: nil, mask: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all incarnations", %{conn: conn} do
      conn = get(conn, Routes.incarnation_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create incarnation" do
    test "renders incarnation when data is valid", %{conn: conn} do
      conn = post(conn, Routes.incarnation_path(conn, :create), incarnation: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.incarnation_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "answer" => "some answer",
               "answers" => [],
               "concept" => "some concept",
               "mask" => "some mask"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.incarnation_path(conn, :create), incarnation: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update incarnation" do
    setup [:create_incarnation]

    test "renders incarnation when data is valid", %{conn: conn, incarnation: %Incarnation{id: id} = incarnation} do
      conn = put(conn, Routes.incarnation_path(conn, :update, incarnation), incarnation: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.incarnation_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "answer" => "some updated answer",
               "answers" => [],
               "concept" => "some updated concept",
               "mask" => "some updated mask"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, incarnation: incarnation} do
      conn = put(conn, Routes.incarnation_path(conn, :update, incarnation), incarnation: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete incarnation" do
    setup [:create_incarnation]

    test "deletes chosen incarnation", %{conn: conn, incarnation: incarnation} do
      conn = delete(conn, Routes.incarnation_path(conn, :delete, incarnation))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.incarnation_path(conn, :show, incarnation))
      end
    end
  end

  defp create_incarnation(_) do
    incarnation = incarnation_fixture()
    %{incarnation: incarnation}
  end
end
