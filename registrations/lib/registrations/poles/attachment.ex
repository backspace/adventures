defmodule Registrations.Poles.Attachment do
  @moduledoc """
  Binary attachment (photo) on a pole or a puzzlet. Exactly one of
  `pole_id` or `puzzlet_id` must be set, enforced at the DB layer.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "poles"
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "attachments" do
    field :pole_id, :binary_id
    field :puzzlet_id, :binary_id
    field :data, :binary
    field :content_type, :string
    field :byte_size, :integer
    field :creator_id, :binary_id

    timestamps()
  end

  @max_bytes 8 * 1024 * 1024
  @allowed_types ~w(image/jpeg image/png image/webp image/heic)

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:pole_id, :puzzlet_id, :data, :content_type, :byte_size, :creator_id])
    |> validate_required([:data, :content_type, :byte_size, :creator_id])
    |> validate_inclusion(:content_type, @allowed_types,
      message: "must be JPEG, PNG, WEBP, or HEIC"
    )
    |> validate_number(:byte_size, less_than_or_equal_to: @max_bytes,
      message: "must be #{div(@max_bytes, 1024 * 1024)} MB or smaller"
    )
    |> validate_parent()
  end

  defp validate_parent(changeset) do
    pole_id = get_field(changeset, :pole_id)
    puzzlet_id = get_field(changeset, :puzzlet_id)

    case {pole_id, puzzlet_id} do
      {nil, nil} ->
        add_error(changeset, :base, "must belong to a pole or a puzzlet")

      {p, q} when not is_nil(p) and not is_nil(q) ->
        add_error(changeset, :base, "cannot belong to both a pole and a puzzlet")

      _ ->
        changeset
    end
  end
end
