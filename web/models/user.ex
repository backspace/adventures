defmodule Cr2016site.User do
  use Cr2016site.Web, :model

  schema "users" do
    field :email, Cr2016site.DowncasedString
    field :crypted_password, :string
    field :password, :string, virtual: true
    field :recovery_hash, :string

    field :new_password, :string, virtual: true
    field :new_password_confirmation, :string, virtual: true
    field :current_password, :string, virtual: true

    field :admin, :boolean

    field :attending, :boolean

    field :display_size, :string
    field :txt, :boolean
    field :data, :boolean
    field :svg, :boolean
    field :number, :string

    field :txt_confirmation_sent, :string
    field :txt_confirmation_received, :string

    field :teamed, :boolean, virtual: true

    field :name, :string
    field :team_emails, Cr2016site.DowncasedString
    field :proposed_team_name, :string

    field :risk_aversion, :integer
    field :accessibility, :string

    field :comments, :string
    field :source, :string

    timestamps()
  end

  @required_fields ~w(email password)
  @optional_fields ~w(name team_emails proposed_team_name risk_aversion accessibility comments source svg display_size data number txt_confirmation_received)

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:email)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 5)
  end

  def details_changeset(model, params \\ %{}) do
    required_fields = case Application.get_env(:cr2016site, :request_confirmation) do
      true -> ~w(attending)
      _ -> []
    end ++ ~w(txt)

    model = model
    |> cast(params, required_fields, @optional_fields)

    model = case get_field(model, :txt) do
      true -> model |> validate_required(:number) |> validate_format(:number, ~r/\d{10}/, message: "must be ten digits")
      _ -> model
    end

    # FIXME ugh hideous!
    case model.changes[:number] do
      nil ->
        case model.changes[:txt_confirmation_received] do
          nil -> model
          _ ->
            model
            |> validate_txt_confirmation
          end
      _ ->
        case model.valid? do
          true ->
            random = Cr2016site.Random.uniform(999999)
            confirmation = String.pad_leading("#{random}", 6, "0")
            model |> Ecto.Changeset.put_change(:txt_confirmation_sent, confirmation)
          _ -> model
        end
    end
  end

  def confirmation_changeset(model, params \\ %{}) do
    model
    |> cast(params, [], ["txt_confirmation_received"])
    |> validate_txt_confirmation
  end

  def account_changeset(model, params \\ %{}) do
    model
    |> cast(params, ~w(current_password new_password new_password_confirmation), [])
    # FIXME duplicated from changeset
    |> validate_length(:new_password, min: 5)
    |> validate_confirmation(:new_password)
  end

  def deletion_changeset(model, params \\ %{}) do
    model
    |> cast(params, ~w(current_password), [])
  end

  def reset_changeset(model) do
    if model do
      model
      |> cast(%{}, [], ~w(recovery_hash))
    end
  end

  def perform_reset_changeset(model, params \\ %{}) do
    model
    |> cast(params, ~w(recovery_hash new_password new_password_confirmation), [])
    |> validate_length(:new_password, min: 5)
    |> validate_confirmation(:new_password)
  end

  defp validate_txt_confirmation(model) do
    model
    |> validate_change(:txt_confirmation_received, fn :txt_confirmation_received, txt_confirmation_received ->
      if txt_confirmation_received == get_field(model, :txt_confirmation_sent) do
        []
      else
        [txt_confirmation_received: "must equal confirmation txted"]
      end
    end)
  end
end
