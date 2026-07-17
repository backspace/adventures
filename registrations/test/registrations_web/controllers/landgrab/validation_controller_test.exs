defmodule RegistrationsWeb.Landgrab.ValidationControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Validations

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
      body = conn |> get("/landgrab/validation/mine") |> json_response(403)
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
      pole = insert(:pole, creator: author, status: :draft, accuracy_m: 12.5)

      {:ok, _} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body = conn |> get("/landgrab/validation/mine") |> json_response(200)
      assert length(body["pole_validations"]) == 1
      assert hd(body["pole_validations"])["status"] == "assigned"
      assert hd(body["pole_validations"])["pole"]["id"] == pole.id
      # Accuracy is exposed so the validator map can draw the uncertainty circle.
      assert hd(body["pole_validations"])["pole"]["accuracy_m"] == 12.5
    end

    test "validator can transition assigned → in_progress → submitted",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body =
        conn
        |> patch("/landgrab/validation/pole-validations/#{validation.id}", %{"status" => "in_progress"})
        |> json_response(200)

      assert body["status"] == "in_progress"

      body =
        conn
        |> patch("/landgrab/validation/pole-validations/#{validation.id}", %{"status" => "submitted"})
        |> json_response(200)

      assert body["status"] == "submitted"
    end

    test "submitting the form with no changes is a clean endorsement",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, v} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body =
        conn
        |> post("/landgrab/validation/pole-validations/#{v.id}/submit", %{
          "physically_verified" => true,
          "suggestions" => []
        })
        |> json_response(200)

      assert body["status"] == "submitted"
      assert body["physically_verified"] == true
      assert body["comments"] == []
    end

    test "submitting with edits records them as suggestions",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft, label: "Old")
      {:ok, v} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body =
        conn
        |> post("/landgrab/validation/pole-validations/#{v.id}/submit", %{
          "physically_verified" => true,
          "suggestions" => [
            %{"field" => "label", "suggested_value" => "The Forks"},
            %{
              "field" => "location",
              "suggested_value" => ~s({"latitude":49.9,"longitude":-97.1,"accuracy_m":6.0})
            }
          ]
        })
        |> json_response(200)

      assert body["status"] == "submitted"
      fields = Enum.map(body["comments"], & &1["field"]) |> Enum.sort()
      assert fields == ["label", "location"]
    end

    test "supervisor accepting a location suggestion moves the pole",
         %{validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft, latitude: 49.0, longitude: -97.0)
      {:ok, v} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      {:ok, submitted} =
        Validations.submit_pole_validation(v, validator.id, %{
          "physically_verified" => true,
          "suggestions" => [
            %{
              "field" => "location",
              "suggested_value" => ~s({"latitude":49.5,"longitude":-97.5,"accuracy_m":5.0})
            }
          ]
        })

      comment = hd(submitted.comments)
      {:ok, _} = Validations.accept_pole_comment(comment)

      moved = Registrations.Repo.get!(Pole, pole.id)
      assert moved.latitude == 49.5
      assert moved.longitude == -97.5
      assert moved.accuracy_m == 5.0
    end

    test "marking a pole unfindable, then supervisor accepting, retires it",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, v} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body =
        conn
        |> post("/landgrab/validation/pole-validations/#{v.id}/unfindable", %{
          "overall_notes" => "no pole at these coordinates"
        })
        |> json_response(200)

      assert body["status"] == "unfindable"
      assert body["overall_notes"] == "no pole at these coordinates"

      reloaded = Validations.get_pole_validation(v.id)
      {:ok, _} = Validations.accept_pole_validation(reloaded)
      assert Registrations.Repo.get!(Pole, pole.id).status == :retired
    end

    test "submitting a puzzlet form endorses / records suggestions",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      puzzlet = insert(:puzzlet, creator: author, status: :draft, difficulty: 3)
      {:ok, v} = Validations.assign_puzzlet_validation(puzzlet.id, validator.id, supervisor.id)

      # Clean endorse.
      endorsed =
        conn
        |> post("/landgrab/validation/puzzlet-validations/#{v.id}/submit",
          %{"suggestions" => []})
        |> json_response(200)

      assert endorsed["status"] == "submitted"
      assert endorsed["comments"] == []

      # A fresh assignment can carry suggestions.
      puzzlet2 = insert(:puzzlet, creator: author, status: :draft, difficulty: 3)
      {:ok, v2} = Validations.assign_puzzlet_validation(puzzlet2.id, validator.id, supervisor.id)

      body =
        conn
        |> post("/landgrab/validation/puzzlet-validations/#{v2.id}/submit", %{
          "suggestions" => [
            %{"field" => "difficulty", "suggested_value" => "5"},
            %{"field" => "accessibility_tags", "suggested_value" => ~s(["stairs"])}
          ]
        })
        |> json_response(200)

      assert body["status"] == "submitted"
      fields = Enum.map(body["comments"], & &1["field"]) |> Enum.sort()
      assert fields == ["accessibility_tags", "difficulty"]

      # Supervisor accepting the difficulty suggestion applies it.
      diff = Enum.find(body["comments"], &(&1["field"] == "difficulty"))
      comment = Validations.get_puzzlet_comment(diff["id"])
      {:ok, _} = Validations.accept_puzzlet_comment(comment)
      assert Registrations.Repo.get!(Registrations.Landgrab.Puzzlet, puzzlet2.id).difficulty == 5
    end

    test "scan resolves matched / other / unknown for the validator",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      tapped = insert(:pole, creator: author, status: :draft, barcode: "TAP-#{System.unique_integer([:positive])}")
      other = insert(:pole, creator: author, status: :draft, barcode: "OTH-#{System.unique_integer([:positive])}")
      {:ok, tv} = Validations.assign_pole_validation(tapped.id, validator.id, supervisor.id)
      {:ok, ov} = Validations.assign_pole_validation(other.id, validator.id, supervisor.id)

      matched =
        conn
        |> get("/landgrab/validation/scan?barcode=#{tapped.barcode}&validation_id=#{tv.id}")
        |> json_response(200)

      assert matched["outcome"] == "matched"
      assert matched["validation_id"] == tv.id

      routed =
        conn
        |> get("/landgrab/validation/scan?barcode=#{other.barcode}&validation_id=#{tv.id}")
        |> json_response(200)

      assert routed["outcome"] == "other"
      assert routed["validation_id"] == ov.id

      unknown =
        conn
        |> get("/landgrab/validation/scan?barcode=NOSUCH&validation_id=#{tv.id}")
        |> json_response(200)

      assert unknown["outcome"] == "unknown"
      assert unknown["validation_id"] == nil
    end

    test "validator cannot accept (supervisor-only transition)",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")

      submitted =
        validation.id
        |> Validations.get_pole_validation()
        |> then(fn v ->
          {:ok, v} = Validations.transition_pole_validation_as_validator(v, validator.id, "submitted")
          v
        end)

      body =
        conn
        |> patch("/landgrab/validation/pole-validations/#{submitted.id}", %{"status" => "accepted"})
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
        |> post("/landgrab/validation/pole-validations/#{validation.id}/comments", %{
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
        |> post("/landgrab/validation/pole-validations/#{validation.id}/comments", %{
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
        |> patch("/landgrab/validation/pole-validations/#{validation.id}", %{"status" => "in_progress"})
        |> json_response(403)

      assert body["error"]["code"] == "not_assignee"
    end

    test "puzzlet validation lifecycle works the same",
         %{conn: conn, validator: validator, author: author, supervisor: supervisor} do
      puzzlet = insert(:puzzlet, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_puzzlet_validation(puzzlet.id, validator.id, supervisor.id)

      body =
        conn
        |> patch("/landgrab/validation/puzzlet-validations/#{validation.id}", %{"status" => "in_progress"})
        |> json_response(200)

      assert body["status"] == "in_progress"

      body =
        conn
        |> post("/landgrab/validation/puzzlet-validations/#{validation.id}/comments", %{
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
        |> patch("/landgrab/validation/pole-comments/#{comment.id}", %{"comment" => "edited"})
        |> json_response(200)

      assert body["comment"] == "edited"

      conn
      |> delete("/landgrab/validation/pole-comments/#{comment.id}")
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

      assert Registrations.Repo.get!(Pole, pole.id).status == :in_review
    end

    test "assigning leaves a non-draft pole's status alone" do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      supervisor = insert(:user, email: unique_email("s"))
      pole = insert(:pole, creator: author, status: :validated)

      {:ok, _} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      assert Registrations.Repo.get!(Pole, pole.id).status == :validated
    end
  end
end
