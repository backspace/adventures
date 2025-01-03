defmodule RegistrationsWeb.User do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema
  use PowAssent.Ecto.Schema

  use Pow.Extension.Ecto.Schema,
    extensions: [PowResetPassword, PowInvitation, PowPersistentSession]

  use RegistrationsWeb, :model

  alias Registrations.Repo

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    field(:name, :string)

    # pow_user_fields() with overridden email field
    field(:email, RegistrationsWeb.DowncasedString)
    field(:password_hash, :string)
    field(:current_password, :string, virtual: true)
    field(:password, :string, virtual: true)
    field(:confirm_password, :string, virtual: true)

    field(:invitation_token, :string)
    field(:invitation_accepted_at, :utc_datetime)

    belongs_to(:invited_by, RegistrationsWeb.User, type: :binary_id)
    has_many(:invited_users, RegistrationsWeb.User, foreign_key: :invited_by_id)

    has_many(:user_identities, Registrations.UserIdentities.UserIdentity,
      foreign_key: :user_id,
      on_delete: :delete_all
    )

    field(:admin, :boolean)

    field(:attending, :boolean)

    belongs_to(:team, RegistrationsWeb.Team, type: :binary_id)

    field(:team_emails, RegistrationsWeb.DowncasedString)
    field(:proposed_team_name, :string)

    field(:risk_aversion, :integer)
    field(:accessibility, :string)

    field(:comments, :string)
    field(:source, :string)

    # specific to unmnemonic-devices
    field(:voicepass, :string)

    timestamps()
  end

  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
  end

  @required_fields ~w(email password)a
  @optional_fields ~w(team_emails proposed_team_name risk_aversion accessibility comments source team_id)a

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def old_changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 5)
  end

  def details_changeset(model, params \\ %{}) do
    required_fields =
      if Application.get_env(:registrations, :request_confirmation) do
        ~w(attending)a
      else
        []
      end

    model
    |> cast(params, required_fields ++ @optional_fields)
    |> validate_required(required_fields)
  end

  def name_changeset(model, params \\ %{}) do
    required_fields = ~w(name)a

    model
    |> cast(params, required_fields)
    |> validate_required(required_fields)
  end

  def voicepass_changeset(model, params \\ %{}) do
    required_fields = ~w(voicepass)a

    model
    |> cast(params, required_fields)
    |> validate_required(required_fields)
  end

  def account_changeset(model, params \\ %{}) do
    model
    |> cast(params, ~w(current_password new_password new_password_confirmation)a, [])
    # FIXME duplicated from changeset
    |> validate_length(:new_password, min: 5)
    |> validate_confirmation(:new_password)
  end

  def deletion_changeset(model, params \\ %{}) do
    cast(model, params, ~w(current_password)a, [])
  end

  def reset_changeset(model) do
    if model do
      cast(model, %{}, [], ~w(recovery_hash)a)
    end
  end

  def perform_reset_changeset(model, params \\ %{}) do
    model
    |> cast(params, ~w(recovery_hash new_password new_password_confirmation)a, [])
    |> validate_length(:new_password, min: 5)
    |> validate_confirmation(:new_password)
  end

  def voicepass_candidates do
    file = File.open!("config/sixteen.txt")
    all_voicepasses = Enum.map(IO.stream(file, :line), &String.trim/1)

    existing_voicepasse_prefixes =
      from(u in RegistrationsWeb.User,
        select: u.voicepass
      )
      |> Repo.all()
      |> Enum.filter(& &1)
      |> Enum.map(fn str -> String.slice(str, 0, 4) end)

    Enum.reject(all_voicepasses, fn line ->
      Enum.member?(
        existing_voicepasse_prefixes,
        String.slice(line, 0, 4)
      )
    end)
  end
end
