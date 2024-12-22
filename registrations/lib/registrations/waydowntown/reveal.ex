defmodule Registrations.Waydowntown.Reveal do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Registrations.Repo
  alias Registrations.Waydowntown.Answer
  alias Registrations.Waydowntown.Run

  @primary_key {:id, :binary_id, autogenerate: true}
  @schema_prefix "waydowntown"
  @foreign_key_type :binary_id

  schema "reveals" do
    belongs_to(:answer, Registrations.Waydowntown.Answer)
    belongs_to(:run, Registrations.Waydowntown.Run)
    belongs_to(:user, RegistrationsWeb.User)

    timestamps(updated_at: false)
  end

  def changeset(reveal, attrs) do
    reveal
    |> cast(attrs, [:answer_id, :run_id, :user_id])
    |> validate_required([:answer_id, :run_id, :user_id])
    |> foreign_key_constraint(:answer_id)
    |> foreign_key_constraint(:run_id)
    |> foreign_key_constraint(:user_id)
    |> validate_answer_connected_to_run()
  end

  defp validate_answer_connected_to_run(changeset) do
    run_id = get_field(changeset, :run_id)

    validate_change(changeset, :answer_id, fn :answer_id, answer_id ->
      if is_nil(run_id) do
        [answer_id: "Run not found"]
      else
        case Repo.get(Run, run_id) do
          nil ->
            [answer_id: "Run not found"]

          run ->
            specification_id = run.specification_id

            if Repo.exists?(from(a in Answer, where: a.id == ^answer_id and a.specification_id == ^specification_id)) do
              []
            else
              [answer_id: "Answer not connected to run"]
            end
        end
      end
    end)
  end
end
