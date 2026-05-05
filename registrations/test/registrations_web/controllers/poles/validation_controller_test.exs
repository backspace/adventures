defmodule RegistrationsWeb.Poles.ValidationControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts
  alias Registrations.Poles.Validations

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

  describe "without the validator role" do
    setup ctx do
      user = insert(:user, email: unique_email("noval"))
      %{conn: authed_conn(ctx, user)}
    end

    test "GET /poles/validation/mine is forbidden", %{conn: conn} do
      body = conn |> get("/poles/validation/mine") |> json_response(403)
      assert body["error"]["code"] == "forbidden"
    end
  end

  describe "with the validator role" do
    setup ctx do
      validator = insert(:user, email: unique_email("validator"))
      Accounts.assign_role(validator.id, "validator")

      author = insert(:user, email: unique_email("author"))
      supervisor = insert(:user, email: unique_email("super"))

      %{
        conn: authed_conn(ctx, validator),
        validator: validator,
        author: author,
        supervisor: supervisor
      }
    end

    test "GET /poles/validation/mine lists assignments",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, _} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body = conn |> get("/poles/validation/mine") |> json_response(200)
      assert length(body["pole_validations"]) == 1
      assert hd(body["pole_validations"])["status"] == "assigned"
      assert hd(body["pole_validations"])["pole"]["id"] == pole.id
    end

    test "validator can transition assigned → in_progress → submitted",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body =
        conn
        |> patch("/poles/validation/pole-validations/#{validation.id}", %{"status" => "in_progress"})
        |> json_response(200)

      assert body["status"] == "in_progress"

      body =
        conn
        |> patch("/poles/validation/pole-validations/#{validation.id}", %{"status" => "submitted"})
        |> json_response(200)

      assert body["status"] == "submitted"
    end

    test "validator cannot accept (supervisor-only transition)",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")

      submitted =
        Validations.get_pole_validation(validation.id)
        |> then(fn v ->
          {:ok, v} = Validations.transition_pole_validation_as_validator(v, validator.id, "submitted")
          v
        end)

      body =
        conn
        |> patch("/poles/validation/pole-validations/#{submitted.id}", %{"status" => "accepted"})
        |> json_response(422)

      assert body["errors"] != nil
    end

    test "validator can add a comment while in_progress",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")

      body =
        conn
        |> post("/poles/validation/pole-validations/#{validation.id}/comments", %{
          "field" => "label",
          "comment" => "label is misspelled",
          "suggested_value" => "The Forks"
        })
        |> json_response(201)

      assert body["field"] == "label"
      assert body["suggested_value"] == "The Forks"
      assert body["status"] == "pending"
    end

    test "comment add is rejected when validation is not in_progress",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body =
        conn
        |> post("/poles/validation/pole-validations/#{validation.id}/comments", %{
          "field" => "label",
          "comment" => "x"
        })
        |> json_response(409)

      assert body["error"]["code"] == "not_in_progress"
    end

    test "validator cannot touch someone else's validation",
         %{conn: conn, author: author, supervisor: supervisor} do
      other_validator = insert(:user, email: unique_email("ov"))
      Accounts.assign_role(other_validator.id, "validator")

      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, other_validator.id, supervisor.id)

      body =
        conn
        |> patch("/poles/validation/pole-validations/#{validation.id}", %{"status" => "in_progress"})
        |> json_response(403)

      assert body["error"]["code"] == "not_assignee"
    end

    test "puzzlet validation lifecycle works the same",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      puzzlet = insert(:puzzlet, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_puzzlet_validation(puzzlet.id, validator.id, supervisor.id)

      body =
        conn
        |> patch("/poles/validation/puzzlet-validations/#{validation.id}", %{"status" => "in_progress"})
        |> json_response(200)

      assert body["status"] == "in_progress"

      body =
        conn
        |> post("/poles/validation/puzzlet-validations/#{validation.id}/comments", %{
          "field" => "answer",
          "suggested_value" => "1989"
        })
        |> json_response(201)

      assert body["field"] == "answer"
    end

    test "validator can edit and delete their own pending comment",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")

      {:ok, comment} =
        Validations.add_pole_comment(validation, validator.id, %{
          "field" => "label",
          "comment" => "first try"
        })

      body =
        conn
        |> patch("/poles/validation/pole-comments/#{comment.id}", %{"comment" => "edited"})
        |> json_response(200)

      assert body["comment"] == "edited"

      conn
      |> delete("/poles/validation/pole-comments/#{comment.id}")
      |> response(204)
    end
  end

  describe "side effects" do
    test "assigning a pole flips its status to in_review" do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      supervisor = insert(:user, email: unique_email("s"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, _} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      assert Registrations.Repo.get!(Registrations.Poles.Pole, pole.id).status == :in_review
    end

    test "assigning leaves a non-draft pole's status alone" do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      supervisor = insert(:user, email: unique_email("s"))
      pole = insert(:pole, creator: author, status: :validated)

      {:ok, _} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      assert Registrations.Repo.get!(Registrations.Poles.Pole, pole.id).status == :validated
    end
  end

end
