defmodule AdventureRegistrationsWeb.User do
  use AdventureRegistrationsWeb, :model
  alias AdventureRegistrations.Repo

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    field :email, AdventureRegistrationsWeb.DowncasedString
    field :crypted_password, :string
    field :password, :string, virtual: true
    field :recovery_hash, :string

    field :new_password, :string, virtual: true
    field :new_password_confirmation, :string, virtual: true
    field :current_password, :string, virtual: true

    field :admin, :boolean

    field :attending, :boolean

    field :teamed, :boolean, virtual: true

    field :team_emails, AdventureRegistrationsWeb.DowncasedString
    field :proposed_team_name, :string

    field :risk_aversion, :integer
    field :accessibility, :string

    field :comments, :string
    field :source, :string

    # specific to unmnemonic-devices
    field :voicepass, :string

    timestamps()
  end

  @required_fields ~w(email password)a
  @optional_fields ~w(team_emails proposed_team_name risk_aversion accessibility comments source)a

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 5)
  end

  def details_changeset(model, params \\ %{}) do
    required_fields = case Application.get_env(:adventure_registrations, :request_confirmation) do
      true -> ~w(attending)a
      _ -> []
    end

    model
    |> cast(params, required_fields ++ @optional_fields)
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
    model
    |> cast(params, ~w(current_password)a, [])
  end

  def reset_changeset(model) do
    if model do
      model
      |> cast(%{}, [], ~w(recovery_hash)a)
    end
  end

  def perform_reset_changeset(model, params \\ %{}) do
    model
    |> cast(params, ~w(recovery_hash new_password new_password_confirmation)a, [])
    |> validate_length(:new_password, min: 5)
    |> validate_confirmation(:new_password)
  end

  def voicepass_candidates() do
    file = File.open!("config/sixteen.txt")
    all_voicepasses = Enum.map(IO.stream(file, :line), &String.trim/1)

    existing_voicepasse_prefixes =
      Repo.all(
        from(u in AdventureRegistrationsWeb.User,
          select: u.voicepass
        )
      )
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
