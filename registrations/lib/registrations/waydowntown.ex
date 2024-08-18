defmodule Registrations.Waydowntown do
  @moduledoc """
  The Waydowntown context.
  """

  import Ecto.Query, warn: false
  alias Registrations.Repo

  alias Registrations.Waydowntown.Game
  alias Registrations.Waydowntown.Incarnation

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Repo.all(Game) |> Repo.preload(incarnation: [region: [:parent]])
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id), do: Repo.get!(Game, id) |> Repo.preload(incarnation: [region: [:parent]])

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs \\ %{}, incarnation_filter \\ nil) do
    incarnation = get_random_incarnation(incarnation_filter)

    %Game{}
    |> Game.changeset(Map.put(attrs, "incarnation_id", incarnation.id))
    |> Repo.insert()
  end

  defp get_random_incarnation(nil), do: Repo.all(Incarnation) |> Enum.random()

  defp get_random_incarnation(concept) do
    Incarnation
    |> where([i], i.concept == ^concept)
    |> Repo.all()
    |> Enum.random()
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a game.

  ## Examples

      iex> delete_game(game)
      {:ok, %Game{}}

      iex> delete_game(game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(game)
      %Ecto.Changeset{data: %Game{}}

  """
  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  alias Registrations.Waydowntown.Incarnation

  @doc """
  Returns the list of incarnations.

  ## Examples

      iex> list_incarnations()
      [%Incarnation{}, ...]

  """
  def list_incarnations do
    Repo.all(Incarnation)
  end

  @doc """
  Gets a single incarnation.

  Raises `Ecto.NoResultsError` if the Incarnation does not exist.

  ## Examples

      iex> get_incarnation!(123)
      %Incarnation{}

      iex> get_incarnation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_incarnation!(id), do: Repo.get!(Incarnation, id)

  @doc """
  Creates a incarnation.

  ## Examples

      iex> create_incarnation(%{field: value})
      {:ok, %Incarnation{}}

      iex> create_incarnation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_incarnation(attrs \\ %{}) do
    %Incarnation{}
    |> Incarnation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a incarnation.

  ## Examples

      iex> update_incarnation(incarnation, %{field: new_value})
      {:ok, %Incarnation{}}

      iex> update_incarnation(incarnation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_incarnation(%Incarnation{} = incarnation, attrs) do
    incarnation
    |> Incarnation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a incarnation.

  ## Examples

      iex> delete_incarnation(incarnation)
      {:ok, %Incarnation{}}

      iex> delete_incarnation(incarnation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_incarnation(%Incarnation{} = incarnation) do
    Repo.delete(incarnation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking incarnation changes.

  ## Examples

      iex> change_incarnation(incarnation)
      %Ecto.Changeset{data: %Incarnation{}}

  """
  def change_incarnation(%Incarnation{} = incarnation, attrs \\ %{}) do
    Incarnation.changeset(incarnation, attrs)
  end

  alias Registrations.Waydowntown.Region

  @doc """
  Returns the list of regions.

  ## Examples

      iex> list_regions()
      [%Region{}, ...]

  """
  def list_regions do
    Repo.all(Region)
  end

  @doc """
  Gets a single region.

  Raises `Ecto.NoResultsError` if the Region does not exist.

  ## Examples

      iex> get_region!(123)
      %Region{}

      iex> get_region!(456)
      ** (Ecto.NoResultsError)

  """
  def get_region!(id), do: Repo.get!(Region, id)

  @doc """
  Creates a region.

  ## Examples

      iex> create_region(%{field: value})
      {:ok, %Region{}}

      iex> create_region(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_region(attrs \\ %{}) do
    %Region{}
    |> Region.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a region.

  ## Examples

      iex> update_region(region, %{field: new_value})
      {:ok, %Region{}}

      iex> update_region(region, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_region(%Region{} = region, attrs) do
    region
    |> Region.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a region.

  ## Examples

      iex> delete_region(region)
      {:ok, %Region{}}

      iex> delete_region(region)
      {:error, %Ecto.Changeset{}}

  """
  def delete_region(%Region{} = region) do
    Repo.delete(region)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking region changes.

  ## Examples

      iex> change_region(region)
      %Ecto.Changeset{data: %Region{}}

  """
  def change_region(%Region{} = region, attrs \\ %{}) do
    Region.changeset(region, attrs)
  end

  alias Registrations.Waydowntown.Answer

  @doc """
  Returns the list of answers.

  ## Examples

      iex> list_answers()
      [%Answer{}, ...]

  """
  def list_answers do
    Repo.all(Answer)
  end

  @doc """
  Gets a single answer.

  Raises `Ecto.NoResultsError` if the Answer does not exist.

  ## Examples

      iex> get_answer!(123)
      %Answer{}

      iex> get_answer!(456)
      ** (Ecto.NoResultsError)

  """
  def get_answer!(id), do: Repo.get!(Answer, id)

  @doc """
  Creates an answer.

  ## Examples

      iex> create_answer(%{field: value})
      {:ok, %Answer{}}

      iex> create_answer(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_answer(%{"answer" => answer_text, "game_id" => game_id}) do
    game = get_game!(game_id)
    incarnation = game.incarnation

    %Answer{}
    |> Answer.changeset(%{
      "answer" => answer_text,
      "correct" => check_answer_correctness(incarnation, answer_text),
      "game_id" => game_id
    })
    |> Repo.insert()
    |> case do
      {:ok, answer} ->
        if answer.correct and single_answer_game?(incarnation) do
          update_game_winner(game, answer)
        end

        {:ok, Repo.preload(answer, :game)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp check_answer_correctness(
         %Incarnation{concept: "fill_in_the_blank", answer: correct_answer},
         answer_text
       ) do
    String.downcase(String.trim(correct_answer)) == String.downcase(String.trim(answer_text))
  end

  defp check_answer_correctness(
         %Incarnation{concept: "bluetooth_collector", answers: correct_answers},
         answer_text
       ) do
    answer_text in correct_answers
  end

  defp single_answer_game?(%Incarnation{concept: "fill_in_the_blank"}), do: true
  defp single_answer_game?(_), do: false

  defp update_game_winner(game, answer) do
    game
    |> Game.changeset(%{winner_answer_id: answer.id})
    |> Repo.update!()
  end

  @doc """
  Updates a answer.

  ## Examples

      iex> update_answer(answer, %{field: new_value})
      {:ok, %Answer{}}

      iex> update_answer(answer, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_answer(%Answer{} = answer, attrs) do
    answer
    |> Answer.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a answer.

  ## Examples

      iex> delete_answer(answer)
      {:ok, %Answer{}}

      iex> delete_answer(answer)
      {:error, %Ecto.Changeset{}}

  """
  def delete_answer(%Answer{} = answer) do
    Repo.delete(answer)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking answer changes.

  ## Examples

      iex> change_answer(answer)
      %Ecto.Changeset{data: %Answer{}}

  """
  def change_answer(%Answer{} = answer, attrs \\ %{}) do
    Answer.changeset(answer, attrs)
  end
end
