defmodule RegistrationsWeb.Poles.SupervisionControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts
  alias Registrations.Poles.Pole
  alias Registrations.Poles.Puzzlet
  alias Registrations.Poles.Validations
  alias Registrations.Repo

  defp authed_conn(%{conn: conn}, user) do
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

  describe "without the supervisor role" do
    setup ctx do
      user = insert(:user, email: unique_email("nosup"))
      %{conn: authed_conn(ctx, user)}
    end

    test "GET /poles/supervision/dashboard is forbidden", %{conn: conn} do
      body = conn |> get("/poles/supervision/dashboard") |> json_response(403)
      assert body["error"]["code"] == "forbidden"
    end
  end

  describe "with the supervisor role" do
    setup ctx do
      supervisor = insert(:user, email: unique_email("super"))
      Accounts.assign_role(supervisor.id, "validation_supervisor")
      %{conn: authed_conn(ctx, supervisor), supervisor: supervisor}
    end

    test "lists validators excluding a specific user", %{conn: conn} do
      v1 = insert(:user, email: unique_email("v1"))
      v2 = insert(:user, email: unique_email("v2"))
      Accounts.assign_role(v1.id, "validator")
      Accounts.assign_role(v2.id, "validator")

      body =
        conn
        |> get("/poles/supervision/validators?exclude_user_id=#{v1.id}")
        |> json_response(200)

      ids = Enum.map(body["validators"], & &1["id"])
      refute v1.id in ids
      assert v2.id in ids
    end

    test "assigning a pole creates the validation and flips status", %{conn: conn} do
      validator = insert(:user, email: unique_email("v"))
      Accounts.assign_role(validator.id, "validator")
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      body =
        conn
        |> post("/poles/supervision/poles/#{pole.id}/validations", %{
          "validator_id" => validator.id
        })
        |> json_response(201)

      assert body["status"] == "assigned"
      assert body["pole_id"] == pole.id
      assert Repo.get!(Pole, pole.id).status == :in_review
    end

    test "rejects assigning a pole to its creator", %{conn: conn} do
      author = insert(:user, email: unique_email("a"))
      Accounts.assign_role(author.id, "validator")
      pole = insert(:pole, creator: author, status: :draft)

      body =
        conn
        |> post("/poles/supervision/poles/#{pole.id}/validations", %{
          "validator_id" => author.id
        })
        |> json_response(422)

      assert body["errors"] != nil
    end

    test "accept transitions validation to accepted and pole to validated",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "submitted")

      body =
        conn
        |> patch("/poles/supervision/pole-validations/#{validation.id}", %{"status" => "accepted"})
        |> json_response(200)

      assert body["status"] == "accepted"
      assert Repo.get!(Pole, pole.id).status == :validated
    end

    test "reject transitions pole back to draft", %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "submitted")

      body =
        conn
        |> patch("/poles/supervision/pole-validations/#{validation.id}", %{"status" => "rejected"})
        |> json_response(200)

      assert body["status"] == "rejected"
      assert Repo.get!(Pole, pole.id).status == :draft
    end

    test "accepting a pole comment with suggested_value writes it onto the pole",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft, label: "old")

      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")

      {:ok, comment} =
        Validations.add_pole_comment(validation, validator.id, %{
          "field" => "label",
          "suggested_value" => "The Forks"
        })

      body =
        conn
        |> patch("/poles/supervision/pole-comments/#{comment.id}", %{"status" => "accepted"})
        |> json_response(200)

      assert body["status"] == "accepted"
      assert Repo.get!(Pole, pole.id).label == "The Forks"
    end

    test "accepting a numeric difficulty suggestion parses and applies it",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      puzzlet = insert(:puzzlet, creator: author, difficulty: 3)

      {:ok, validation} = Validations.assign_puzzlet_validation(puzzlet.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_puzzlet_validation_as_validator(validation, validator.id, "in_progress")

      {:ok, comment} =
        Validations.add_puzzlet_comment(validation, validator.id, %{
          "field" => "difficulty",
          "suggested_value" => "7"
        })

      conn
      |> patch("/poles/supervision/puzzlet-comments/#{comment.id}", %{"status" => "accepted"})
      |> json_response(200)

      assert Repo.get!(Puzzlet, puzzlet.id).difficulty == 7
    end

    test "rejecting a comment leaves the target alone",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, label: "keep me", status: :draft)

      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")

      {:ok, comment} =
        Validations.add_pole_comment(validation, validator.id, %{
          "field" => "label",
          "suggested_value" => "DO NOT APPLY"
        })

      conn
      |> patch("/poles/supervision/pole-comments/#{comment.id}", %{"status" => "rejected"})
      |> json_response(200)

      assert Repo.get!(Pole, pole.id).label == "keep me"
    end

    test "supervisor can directly edit a pole regardless of status",
         %{conn: conn} do
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :validated, label: "before")

      body =
        conn
        |> patch("/poles/supervision/poles/#{pole.id}", %{"label" => "after"})
        |> json_response(200)

      assert body["label"] == "after"
      assert Repo.get!(Pole, pole.id).label == "after"
    end

    test "list_poles includes active_validation summary when assigned",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")
      {:ok, _} = Validations.add_pole_comment(validation, validator.id, %{"field" => "label", "comment" => "x"})

      body = conn |> get("/poles/supervision/poles?status=in_review") |> json_response(200)
      target = Enum.find(body["poles"], &(&1["id"] == pole.id))
      assert target != nil
      assert target["active_validation"]["status"] == "in_progress"
      assert target["active_validation"]["comment_count"] == 1
    end

    test "list_poles can filter by status", %{conn: conn} do
      author = insert(:user, email: unique_email("a"))
      _draft = insert(:pole, creator: author, status: :draft, barcode: "FILT-D-#{System.unique_integer([:positive])}")
      _val = insert(:pole, creator: author, status: :validated, barcode: "FILT-V-#{System.unique_integer([:positive])}")

      body = conn |> get("/poles/supervision/poles?status=draft") |> json_response(200)
      assert Enum.all?(body["poles"], &(&1["status"] == "draft"))
    end

    test "GET /poles/:id/validations returns validations with comments",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")
      {:ok, _} = Validations.add_pole_comment(validation, validator.id, %{"field" => "label", "comment" => "x"})

      body = conn |> get("/poles/supervision/poles/#{pole.id}/validations") |> json_response(200)
      assert length(body["validations"]) == 1
      assert hd(body["validations"])["comments"] |> length() == 1
    end

    test "dashboard returns counts including validation breakdowns", %{conn: conn} do
      body = conn |> get("/poles/supervision/dashboard") |> json_response(200)
      assert is_map(body["poles"])
      assert is_map(body["puzzlets"])
      assert is_map(body["pole_validations"])
      assert is_map(body["puzzlet_validations"])
    end
  end
end
