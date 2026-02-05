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

        %{
          user_id: user.id,
          email: @test_email,
          password: @test_password
        }
      else
        %{message: "Database reset complete"}
      end

    conn
    |> put_status(:ok)
    |> json(response)
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
