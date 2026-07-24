defmodule RegistrationsWeb.Landgrab.SupervisionControllerTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts
  alias Registrations.Landgrab.Pole
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.Validations
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
      body = conn |> get("/landgrab/supervision/dashboard") |> json_response(403)
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
        |> get("/landgrab/supervision/validators?exclude_user_id=#{v1.id}")
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
        |> post("/landgrab/supervision/poles/#{pole.id}/validations", %{
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
        |> post("/landgrab/supervision/poles/#{pole.id}/validations", %{
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
        |> patch("/landgrab/supervision/pole-validations/#{validation.id}", %{"status" => "accepted"})
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
        |> patch("/landgrab/supervision/pole-validations/#{validation.id}", %{"status" => "rejected"})
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
        |> patch("/landgrab/supervision/pole-comments/#{comment.id}", %{"status" => "accepted"})
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
      |> patch("/landgrab/supervision/puzzlet-comments/#{comment.id}", %{"status" => "accepted"})
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
      |> patch("/landgrab/supervision/pole-comments/#{comment.id}", %{"status" => "rejected"})
      |> json_response(200)

      assert Repo.get!(Pole, pole.id).label == "keep me"
    end

    test "supervisor can directly edit a pole regardless of status",
         %{conn: conn} do
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :validated, label: "before")

      body =
        conn
        |> patch("/landgrab/supervision/poles/#{pole.id}", %{"label" => "after"})
        |> json_response(200)

      assert body["label"] == "after"
      assert Repo.get!(Pole, pole.id).label == "after"
    end

    test "supervisor can attach and detach a puzzlet's pole while it's still in review",
         %{conn: conn} do
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :validated)
      # in_review = validation underway but not finished; the supervisor must
      # still be able to (re)attach it, mirroring the author's attach flow.
      puzzlet = insert(:puzzlet, creator: author, status: :in_review)

      attached =
        conn
        |> patch("/landgrab/supervision/puzzlets/#{puzzlet.id}", %{"pole_id" => pole.id})
        |> json_response(200)

      assert attached["pole_id"] == pole.id
      assert Repo.get!(Puzzlet, puzzlet.id).pole_id == pole.id

      detached =
        conn
        |> patch("/landgrab/supervision/puzzlets/#{puzzlet.id}", %{"pole_id" => nil})
        |> json_response(200)

      assert detached["pole_id"] == nil
      assert Repo.get!(Puzzlet, puzzlet.id).pole_id == nil
    end

    test "supervisor can edit a puzzlet's region and validator-only flag", %{conn: conn} do
      author = insert(:user, email: unique_email("a"))
      region = insert(:poles_region)
      puzzlet = insert(:puzzlet, creator: author, status: :validated, validator_only: false)

      updated =
        conn
        |> patch("/landgrab/supervision/puzzlets/#{puzzlet.id}", %{
          "region_id" => region.id,
          "validator_only" => true
        })
        |> json_response(200)

      assert updated["region_id"] == region.id
      assert updated["validator_only"] == true

      persisted = Repo.get!(Puzzlet, puzzlet.id)
      assert persisted.region_id == region.id
      assert persisted.validator_only == true

      # And it can be cleared / flipped back off.
      recleared =
        conn
        |> patch("/landgrab/supervision/puzzlets/#{puzzlet.id}", %{
          "region_id" => nil,
          "validator_only" => false
        })
        |> json_response(200)

      assert recleared["region_id"] == nil
      assert recleared["validator_only"] == false
    end

    test "list_poles includes active_validation summary when assigned",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")
      {:ok, _} = Validations.add_pole_comment(validation, validator.id, %{"field" => "label", "comment" => "x"})

      body = conn |> get("/landgrab/supervision/poles?status=in_review") |> json_response(200)
      target = Enum.find(body["poles"], &(&1["id"] == pole.id))
      assert target != nil
      assert target["active_validation"]["status"] == "in_progress"
      assert target["active_validation"]["comment_count"] == 1
    end

    test "list_poles can filter by status", %{conn: conn} do
      author = insert(:user, email: unique_email("a"))
      _draft = insert(:pole, creator: author, status: :draft, barcode: "FILT-D-#{System.unique_integer([:positive])}")
      _val = insert(:pole, creator: author, status: :validated, barcode: "FILT-V-#{System.unique_integer([:positive])}")

      body = conn |> get("/landgrab/supervision/poles?status=draft") |> json_response(200)
      assert Enum.all?(body["poles"], &(&1["status"] == "draft"))
    end

    test "list_puzzlets exposes validator_only (drives the map star)", %{conn: conn} do
      author = insert(:user, email: unique_email("a"))
      vo = insert(:puzzlet, creator: author, status: :draft, validator_only: true)

      body = conn |> get("/landgrab/supervision/puzzlets") |> json_response(200)
      entry = Enum.find(body["puzzlets"], &(&1["id"] == vo.id))
      assert entry["validator_only"] == true
    end

    test "GET /poles/:id/validations returns validations with comments",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, validation} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)
      {:ok, validation} = Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")
      {:ok, _} = Validations.add_pole_comment(validation, validator.id, %{"field" => "label", "comment" => "x"})

      body = conn |> get("/landgrab/supervision/poles/#{pole.id}/validations") |> json_response(200)
      assert length(body["validations"]) == 1
      assert length(hd(body["validations"])["comments"]) == 1
    end

    test "dashboard returns counts including validation breakdowns", %{conn: conn} do
      body = conn |> get("/landgrab/supervision/dashboard") |> json_response(200)
      assert is_map(body["poles"])
      assert is_map(body["puzzlets"])
      assert is_map(body["pole_validations"])
      assert is_map(body["puzzlet_validations"])
    end

    test "reassign swaps the validator on an in-flight validation",
         %{conn: conn, supervisor: supervisor} do
      v1 = insert(:user, email: unique_email("v1"))
      Accounts.assign_role(v1.id, "validator")
      v2 = insert(:user, email: unique_email("v2"))
      Accounts.assign_role(v2.id, "validator")
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, validation} =
        Validations.assign_pole_validation(pole.id, v1.id, supervisor.id)

      body =
        conn
        |> patch("/landgrab/supervision/pole-validations/#{validation.id}/validator", %{
          "validator_id" => v2.id
        })
        |> json_response(200)

      assert body["validator_id"] == v2.id
      assert body["assigned_by_id"] == supervisor.id
    end

    test "reassign refuses once the validation is accepted",
         %{conn: conn, supervisor: supervisor} do
      v1 = insert(:user, email: unique_email("v1"))
      Accounts.assign_role(v1.id, "validator")
      v2 = insert(:user, email: unique_email("v2"))
      Accounts.assign_role(v2.id, "validator")
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, validation} =
        Validations.assign_pole_validation(pole.id, v1.id, supervisor.id)

      {:ok, validation} =
        Validations.transition_pole_validation_as_validator(validation, v1.id, "in_progress")

      {:ok, validation} =
        Validations.transition_pole_validation_as_validator(validation, v1.id, "submitted")

      {:ok, _} = Validations.accept_pole_validation(validation)

      body =
        conn
        |> patch("/landgrab/supervision/pole-validations/#{validation.id}/validator", %{
          "validator_id" => v2.id
        })
        |> json_response(409)

      assert body["error"]["code"] == "terminal_status"
    end

    test "unassign deletes a fresh assignment and flips pole back to draft",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      Accounts.assign_role(validator.id, "validator")
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, validation} =
        Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      assert Repo.get!(Pole, pole.id).status == :in_review

      conn
      |> delete("/landgrab/supervision/pole-validations/#{validation.id}")
      |> response(204)

      refute Validations.get_pole_validation(validation.id)
      assert Repo.get!(Pole, pole.id).status == :draft
    end

    test "unassign refuses once a comment has been added",
         %{conn: conn, supervisor: supervisor} do
      validator = insert(:user, email: unique_email("v"))
      Accounts.assign_role(validator.id, "validator")
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)

      {:ok, validation} =
        Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      {:ok, validation} =
        Validations.transition_pole_validation_as_validator(validation, validator.id, "in_progress")

      {:ok, _} =
        Validations.add_pole_comment(validation, validator.id, %{
          "field" => "label",
          "comment" => "x"
        })

      body =
        conn
        |> delete("/landgrab/supervision/pole-validations/#{validation.id}")
        |> json_response(409)

      assert body["error"]["code"] == "not_unassignable"
      assert Validations.get_pole_validation(validation.id)
    end
  end

  describe "bulk assignment" do
    setup ctx do
      supervisor = insert(:user, email: unique_email("super"))
      Accounts.assign_role(supervisor.id, "validation_supervisor")
      validator = insert(:user, email: unique_email("val"))
      Accounts.assign_role(validator.id, "validator")
      author = insert(:user, email: unique_email("author"))
      %{conn: authed_conn(ctx, supervisor), validator: validator, author: author}
    end

    test "assigns a mixed batch and skips unassignable items", %{
      conn: conn,
      validator: validator,
      author: author
    } do
      pole = insert(:pole, creator: author, status: :draft)
      puzzlet = insert(:puzzlet, creator: author, status: :draft)
      # Already has an active validation → skipped, not duplicated.
      busy_pole = insert(:pole, creator: author, status: :draft)
      other_validator = insert(:user, email: unique_email("other"))
      Accounts.assign_role(other_validator.id, "validator")
      {:ok, _} = Validations.assign_pole_validation(busy_pole.id, other_validator.id, author.id)
      # Authored by the target validator → self-validation, skipped.
      own_puzzlet = insert(:puzzlet, creator: validator, status: :draft)

      body =
        conn
        |> post("/landgrab/supervision/assignments", %{
          "validator_id" => validator.id,
          "pole_ids" => [pole.id, busy_pole.id],
          "puzzlet_ids" => [puzzlet.id, own_puzzlet.id]
        })
        |> json_response(200)

      assert body == %{"assigned" => 2, "skipped" => 2}

      assert Validations.active_validations_by_pole([pole.id])[pole.id].validator_id == validator.id
      assert Validations.active_validations_by_puzzlet([puzzlet.id])[puzzlet.id].validator_id == validator.id
      # The busy pole keeps its original validator.
      assert Validations.active_validations_by_pole([busy_pole.id])[busy_pole.id].validator_id ==
               other_validator.id
    end

    test "requires validator_id", %{conn: conn} do
      conn
      |> post("/landgrab/supervision/assignments", %{"pole_ids" => []})
      |> json_response(400)
    end

    test "ignores validator-only puzzlets (not assigned, not counted)", %{
      conn: conn,
      validator: validator,
      author: author
    } do
      normal = insert(:puzzlet, creator: author, status: :draft)
      vo = insert(:puzzlet, creator: author, status: :draft, validator_only: true)

      body =
        conn
        |> post("/landgrab/supervision/assignments", %{
          "validator_id" => validator.id,
          "pole_ids" => [],
          "puzzlet_ids" => [normal.id, vo.id]
        })
        |> json_response(200)

      assert body == %{"assigned" => 1, "skipped" => 0}
      assert Validations.active_validations_by_puzzlet([vo.id])[vo.id] == nil
    end

    test "a validator-only puzzlet can't be assigned individually", %{
      conn: conn,
      validator: validator,
      author: author
    } do
      vo = insert(:puzzlet, creator: author, status: :draft, validator_only: true)

      body =
        conn
        |> post("/landgrab/supervision/puzzlets/#{vo.id}/validations", %{
          "validator_id" => validator.id
        })
        |> json_response(422)

      assert body["error"]["code"] == "validator_only"
      assert Validations.active_validations_by_puzzlet([vo.id])[vo.id] == nil
    end
  end

  describe "bulk set status (POST /statuses)" do
    setup ctx do
      supervisor = insert(:user, email: unique_email("super"))
      Accounts.assign_role(supervisor.id, "validation_supervisor")
      %{conn: authed_conn(ctx, supervisor), supervisor: supervisor}
    end

    test "approve makes draft poles and puzzlets validated", %{conn: conn} do
      pole = insert(:pole, status: :draft)
      puzzlet = insert(:puzzlet, status: :draft)

      body =
        conn
        |> post("/landgrab/supervision/statuses", %{
          "status" => "validated",
          "pole_ids" => [pole.id],
          "puzzlet_ids" => [puzzlet.id]
        })
        |> json_response(200)

      assert body == %{"poles" => 1, "puzzlets" => 1}
      assert Repo.get(Pole, pole.id).status == :validated
      assert Repo.get(Puzzlet, puzzlet.id).status == :validated
    end

    test "remove retires items and cancels their open validations", %{
      conn: conn,
      supervisor: supervisor
    } do
      validator = insert(:user, email: unique_email("v"))
      Accounts.assign_role(validator.id, "validator")
      author = insert(:user, email: unique_email("a"))
      pole = insert(:pole, creator: author, status: :draft)
      {:ok, v} = Validations.assign_pole_validation(pole.id, validator.id, supervisor.id)

      body =
        conn
        |> post("/landgrab/supervision/statuses", %{
          "status" => "retired",
          "pole_ids" => [pole.id]
        })
        |> json_response(200)

      assert body["poles"] == 1
      assert Repo.get(Pole, pole.id).status == :retired
      # The open validation is cancelled, so it drops off the validator map.
      assert Validations.get_pole_validation(v.id).status == "rejected"
    end

    test "send to draft pulls a validated pole out of play", %{conn: conn} do
      pole = insert(:pole, status: :validated)

      conn
      |> post("/landgrab/supervision/statuses", %{
        "status" => "draft",
        "pole_ids" => [pole.id]
      })
      |> json_response(200)

      assert Repo.get(Pole, pole.id).status == :draft
    end

    test "withdrawn applies to puzzlets", %{conn: conn} do
      puzzlet = insert(:puzzlet, status: :validated)

      conn
      |> post("/landgrab/supervision/statuses", %{
        "status" => "withdrawn",
        "puzzlet_ids" => [puzzlet.id]
      })
      |> json_response(200)

      assert Repo.get(Puzzlet, puzzlet.id).status == :withdrawn
    end

    test "unknown ids are skipped, not errors", %{conn: conn} do
      body =
        conn
        |> post("/landgrab/supervision/statuses", %{
          "status" => "retired",
          "pole_ids" => [Ecto.UUID.generate()]
        })
        |> json_response(200)

      assert body == %{"poles" => 0, "puzzlets" => 0}
    end

    test "an unknown status is a 400", %{conn: conn} do
      body =
        conn
        |> post("/landgrab/supervision/statuses", %{"status" => "banana"})
        |> json_response(400)

      assert body["error"]["code"] == "bad_request"
    end

    test "requires the supervisor role", ctx do
      user = insert(:user, email: unique_email("nosup"))
      conn = authed_conn(ctx, user)

      conn
      |> post("/landgrab/supervision/statuses", %{"status" => "retired"})
      |> json_response(403)
    end
  end
end
