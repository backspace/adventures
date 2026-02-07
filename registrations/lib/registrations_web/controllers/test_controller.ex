defmodule RegistrationsWeb.TestController do
  @moduledoc """
  Controller for test-only endpoints. Only available in test environment.
  Provides database reset functionality for integration testing.
  """
  use RegistrationsWeb, :controller

  alias Registrations.Repo
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Participation
  alias Registrations.Waydowntown.Region
  alias Registrations.Waydowntown.Reveal
  alias Registrations.Waydowntown.Run
  alias Registrations.Waydowntown.Specification
  alias Registrations.Waydowntown.Submission

  @test_email "test@example.com"
  @test_password "TestPassword123!"

  def reset(conn, params) do
    # Delete waydowntown tables in FK order
    Repo.delete_all(Reveal)
    Repo.delete_all(Submission)
    Repo.delete_all(Participation)
    Repo.delete_all(Run)
    Repo.delete_all(Answer)
    Repo.delete_all(Specification)
    Repo.delete_all(Region)

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
        answers: [%Answer{label: "The answer is ____", answer: "correct"}],
        region: region,
        duration: 300
      })

    answer = List.first(specification.answers)

    %{
      specification_id: specification.id,
      answer_id: answer.id,
      correct_answer: "correct"
    }
  end

  defp create_or_reset_test_user do
    case Repo.get_by(RegistrationsWeb.User, email: @test_email) do
      nil ->
        %RegistrationsWeb.User{}
        |> RegistrationsWeb.User.changeset(%{
          email: @test_email,
          password: @test_password,
          password_confirmation: @test_password
        })
        |> Repo.insert!()

      existing_user ->
        # Delete and recreate to ensure clean state
        Repo.delete!(existing_user)

        %RegistrationsWeb.User{}
        |> RegistrationsWeb.User.changeset(%{
          email: @test_email,
          password: @test_password,
          password_confirmation: @test_password
        })
        |> Repo.insert!()
    end
  end
end
