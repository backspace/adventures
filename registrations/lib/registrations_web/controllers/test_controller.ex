defmodule RegistrationsWeb.TestController do
  @moduledoc """
  Controller for test-only endpoints. Only available in test environment.
  Provides database reset functionality for integration testing.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Repo
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Region
  alias Registrations.Waydowntown.Specification

  @test_email "test@example.com"
  @test_password "TestPassword1234"

  def reset(conn, params) do
    # Truncate all waydowntown tables - CASCADE handles foreign key dependencies
    Repo.query!("TRUNCATE waydowntown.reveals, waydowntown.submissions, waydowntown.participations, waydowntown.runs, waydowntown.answers, waydowntown.specifications, waydowntown.regions CASCADE")

    response =
      if params["create_user"] == "true" do
        user = create_or_reset_test_user()

        base_response = %{
          user_id: user.id,
          email: @test_email,
          password: @test_password
        }

        # Optionally create game data based on concept parameter
        case params["game"] do
          "fill_in_the_blank" ->
            game_data = create_fill_in_the_blank_game()
            Map.merge(base_response, game_data)

          "string_collector" ->
            game_data = create_string_collector_game()
            Map.merge(base_response, game_data)

          "orientation_memory" ->
            game_data = create_orientation_memory_game()
            Map.merge(base_response, game_data)

          "string_collector_team" ->
            game_data = create_string_collector_team_game()
            Map.merge(base_response, game_data)

          _ ->
            base_response
        end
      else
        %{message: "Database reset complete"}
      end

    conn
    |> put_status(:ok)
    |> json(response)
  end

  defp create_fill_in_the_blank_game do
    region = Repo.insert!(%Region{name: "Test Region"})

    specification =
      Repo.insert!(%Specification{
        concept: "fill_in_the_blank",
        task_description: "What is the answer to this test?",
        region: region,
        duration: 300
      })

    # Insert answer separately (has_many relationship)
    answer =
      Repo.insert!(%Answer{
        label: "The answer is ____",
        answer: "correct",
        specification_id: specification.id
      })

    %{
      specification_id: specification.id,
      answer_id: answer.id,
      correct_answer: "correct"
    }
  end

  defp create_string_collector_game do
    region = Repo.insert!(%Region{name: "Test Region"})

    specification =
      Repo.insert!(%Specification{
        concept: "string_collector",
        task_description: "Find all the hidden words",
        start_description: "Look around for words",
        region: region,
        duration: 300
      })

    # Insert answers separately (has_many relationship)
    answer1 = Repo.insert!(%Answer{answer: "apple", specification_id: specification.id})
    answer2 = Repo.insert!(%Answer{answer: "banana", specification_id: specification.id})
    answer3 = Repo.insert!(%Answer{answer: "cherry", specification_id: specification.id})

    %{
      specification_id: specification.id,
      correct_answers: ["apple", "banana", "cherry"],
      total_answers: 3,
      answer_ids: [answer1.id, answer2.id, answer3.id]
    }
  end

  defp create_orientation_memory_game do
    region = Repo.insert!(%Region{name: "Test Region"})

    specification =
      Repo.insert!(%Specification{
        concept: "orientation_memory",
        task_description: "Remember the sequence of directions",
        start_description: "Watch the pattern carefully",
        region: region,
        duration: 300
      })

    # Insert ordered answers (order field is required for orientation_memory)
    answer1 = Repo.insert!(%Answer{answer: "north", order: 1, specification_id: specification.id})
    answer2 = Repo.insert!(%Answer{answer: "east", order: 2, specification_id: specification.id})
    answer3 = Repo.insert!(%Answer{answer: "south", order: 3, specification_id: specification.id})

    %{
      specification_id: specification.id,
      ordered_answers: ["north", "east", "south"],
      total_answers: 3,
      answer_ids: [answer1.id, answer2.id, answer3.id]
    }
  end

  defp create_string_collector_team_game do
    region = Repo.insert!(%Region{name: "Test Region"})

    specification =
      Repo.insert!(%Specification{
        concept: "string_collector",
        task_description: "Find all the hidden words",
        start_description: "Look around for words",
        region: region,
        duration: 300
      })

    answer1 = Repo.insert!(%Answer{answer: "apple", specification_id: specification.id})
    answer2 = Repo.insert!(%Answer{answer: "banana", specification_id: specification.id})
    answer3 = Repo.insert!(%Answer{answer: "cherry", specification_id: specification.id})

    # Create second test user
    user2 = create_or_reset_user("test2@example.com", @test_password, "Test User 2")

    %{
      specification_id: specification.id,
      correct_answers: ["apple", "banana", "cherry"],
      total_answers: 3,
      answer_ids: [answer1.id, answer2.id, answer3.id],
      user2_email: "test2@example.com",
      user2_password: @test_password
    }
  end

  defp create_or_reset_test_user do
    create_or_reset_user(@test_email, @test_password, "Test User")
  end

  defp create_or_reset_user(email, password, name) do
    case Repo.get_by(RegistrationsWeb.User, email: email) do
      nil ->
        %RegistrationsWeb.User{}
        |> RegistrationsWeb.User.changeset(%{
          email: email,
          password: password,
          password_confirmation: password
        })
        |> Repo.insert!()
        |> Ecto.Changeset.change(%{name: name})
        |> Repo.update!()

      existing_user ->
        Repo.delete!(existing_user)

        %RegistrationsWeb.User{}
        |> RegistrationsWeb.User.changeset(%{
          email: email,
          password: password,
          password_confirmation: password
        })
        |> Repo.insert!()
        |> Ecto.Changeset.change(%{name: name})
        |> Repo.update!()
    end
  end
end
