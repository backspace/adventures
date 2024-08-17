defmodule Registrations.WaydowntownTest do
  use Registrations.DataCase

  alias Registrations.Waydowntown

  describe "games" do
    alias Registrations.Waydowntown.Game

    @invalid_attrs %{complete: nil}

    test "list_games/0 returns all games" do
      game = insert(:game)
      assert Waydowntown.list_games() == [game]
    end

    test "get_game!/1 returns the game with given id" do
      game = insert(:game)
      assert Waydowntown.get_game!(game.id) == game
    end

    test "create_game/1 with valid data creates a game" do
      valid_attrs = %{complete: true}

      assert {:ok, %Game{} = game} = Waydowntown.create_game(valid_attrs)
      assert game.complete == true
    end

    test "create_game/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Waydowntown.create_game(@invalid_attrs)
    end

    test "update_game/2 with valid data updates the game" do
      game = insert(:game)
      update_attrs = %{complete: false}

      assert {:ok, %Game{} = game} = Waydowntown.update_game(game, update_attrs)
      assert game.complete == false
    end

    test "update_game/2 with invalid data returns error changeset" do
      game = insert(:game)
      assert {:error, %Ecto.Changeset{}} = Waydowntown.update_game(game, @invalid_attrs)
      assert game == Waydowntown.get_game!(game.id)
    end

    test "delete_game/1 deletes the game" do
      game = insert(:game)
      assert {:ok, %Game{}} = Waydowntown.delete_game(game)
      assert_raise Ecto.NoResultsError, fn -> Waydowntown.get_game!(game.id) end
    end

    test "change_game/1 returns a game changeset" do
      game = insert(:game)
      assert %Ecto.Changeset{} = Waydowntown.change_game(game)
    end
  end

  describe "incarnations" do
    alias Registrations.Waydowntown.Incarnation

    @invalid_attrs %{answer: nil, answers: nil, concept: nil, mask: nil}

    test "list_incarnations/0 returns all incarnations" do
      incarnation = insert(:incarnation)
      assert Waydowntown.list_incarnations() == [incarnation]
    end

    test "get_incarnation!/1 returns the incarnation with given id" do
      incarnation = insert(:incarnation)
      assert Waydowntown.get_incarnation!(incarnation.id) == incarnation
    end

    test "create_incarnation/1 with valid data creates a incarnation" do
      valid_attrs = %{
        answer: "some answer",
        answers: [],
        concept: "some concept",
        mask: "some mask"
      }

      assert {:ok, %Incarnation{} = incarnation} = Waydowntown.create_incarnation(valid_attrs)
      assert incarnation.answer == "some answer"
      assert incarnation.answers == []
      assert incarnation.concept == "some concept"
      assert incarnation.mask == "some mask"
    end

    test "create_incarnation/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Waydowntown.create_incarnation(@invalid_attrs)
    end

    test "update_incarnation/2 with valid data updates the incarnation" do
      incarnation = insert(:incarnation)

      update_attrs = %{
        answer: "some updated answer",
        answers: [],
        concept: "some updated concept",
        mask: "some updated mask"
      }

      assert {:ok, %Incarnation{} = incarnation} =
               Waydowntown.update_incarnation(incarnation, update_attrs)

      assert incarnation.answer == "some updated answer"
      assert incarnation.answers == []
      assert incarnation.concept == "some updated concept"
      assert incarnation.mask == "some updated mask"
    end

    test "update_incarnation/2 with invalid data returns error changeset" do
      incarnation = insert(:incarnation)

      assert {:error, %Ecto.Changeset{}} =
               Waydowntown.update_incarnation(incarnation, @invalid_attrs)

      assert incarnation == Waydowntown.get_incarnation!(incarnation.id)
    end

    test "delete_incarnation/1 deletes the incarnation" do
      incarnation = insert(:incarnation)
      assert {:ok, %Incarnation{}} = Waydowntown.delete_incarnation(incarnation)
      assert_raise Ecto.NoResultsError, fn -> Waydowntown.get_incarnation!(incarnation.id) end
    end

    test "change_incarnation/1 returns a incarnation changeset" do
      incarnation = insert(:incarnation)
      assert %Ecto.Changeset{} = Waydowntown.change_incarnation(incarnation)
    end
  end

  describe "regions" do
    alias Registrations.Waydowntown.Region

    @invalid_attrs %{description: nil, name: nil}

    test "list_regions/0 returns all regions" do
      region = insert(:region)
      assert Waydowntown.list_regions() == [region]
    end

    test "get_region!/1 returns the region with given id" do
      region = insert(:region)
      assert Waydowntown.get_region!(region.id) == region
    end

    test "create_region/1 with valid data creates a region" do
      valid_attrs = %{description: "some description", name: "some name"}

      assert {:ok, %Region{} = region} = Waydowntown.create_region(valid_attrs)
      assert region.description == "some description"
      assert region.name == "some name"
    end

    test "create_region/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Waydowntown.create_region(@invalid_attrs)
    end

    test "update_region/2 with valid data updates the region" do
      region = insert(:region)
      update_attrs = %{description: "some updated description", name: "some updated name"}

      assert {:ok, %Region{} = region} = Waydowntown.update_region(region, update_attrs)
      assert region.description == "some updated description"
      assert region.name == "some updated name"
    end

    test "update_region/2 with invalid data returns error changeset" do
      region = insert(:region)
      assert {:error, %Ecto.Changeset{}} = Waydowntown.update_region(region, @invalid_attrs)
      assert region == Waydowntown.get_region!(region.id)
    end

    test "delete_region/1 deletes the region" do
      region = insert(:region)
      assert {:ok, %Region{}} = Waydowntown.delete_region(region)
      assert_raise Ecto.NoResultsError, fn -> Waydowntown.get_region!(region.id) end
    end

    test "change_region/1 returns a region changeset" do
      region = insert(:region)
      assert %Ecto.Changeset{} = Waydowntown.change_region(region)
    end
  end

  describe "answers" do
    alias Registrations.Waydowntown.Answer

    @invalid_attrs %{answer: nil, correct: nil}

    test "list_answers/0 returns all answers" do
      answer = insert(:answer)
      assert Waydowntown.list_answers() == [answer]
    end

    test "get_answer!/1 returns the answer with given id" do
      answer = insert(:answer)
      assert Waydowntown.get_answer!(answer.id) == answer
    end

    test "create_answer/1 with valid data creates a answer" do
      valid_attrs = %{answer: "some answer", correct: true}

      assert {:ok, %Answer{} = answer} = Waydowntown.create_answer(valid_attrs)
      assert answer.answer == "some answer"
      assert answer.correct == true
    end

    test "create_answer/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Waydowntown.create_answer(@invalid_attrs)
    end

    test "update_answer/2 with valid data updates the answer" do
      answer = insert(:answer)
      update_attrs = %{answer: "some updated answer", correct: false}

      assert {:ok, %Answer{} = answer} = Waydowntown.update_answer(answer, update_attrs)
      assert answer.answer == "some updated answer"
      assert answer.correct == false
    end

    test "update_answer/2 with invalid data returns error changeset" do
      answer = insert(:answer)
      assert {:error, %Ecto.Changeset{}} = Waydowntown.update_answer(answer, @invalid_attrs)
      assert answer == Waydowntown.get_answer!(answer.id)
    end

    test "delete_answer/1 deletes the answer" do
      answer = insert(:answer)
      assert {:ok, %Answer{}} = Waydowntown.delete_answer(answer)
      assert_raise Ecto.NoResultsError, fn -> Waydowntown.get_answer!(answer.id) end
    end

    test "change_answer/1 returns a answer changeset" do
      answer = insert(:answer)
      assert %Ecto.Changeset{} = Waydowntown.change_answer(answer)
    end
  end
end
