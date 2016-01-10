defmodule Cr2016site.Message do
  use Cr2016site.Web, :model

  schema "messages" do
    field :subject, :string
    field :content, :string
    field :rendered_content, :string
    field :ready, :boolean, default: false
    field :postmarked_at, Ecto.Date

    timestamps
  end

  @required_fields ~w(subject content ready postmarked_at)
  @optional_fields ~w(rendered_content)

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    File.write("/tmp/email.html", Phoenix.View.render_to_string(Cr2016site.EmailView, "welcome.html", %{layout: {Cr2016site.EmailView, "layout.html"}}))
    inline_result = Porcelain.exec("ruby", ["lib/cr2016site/inline-email.rb", Cr2016site.Endpoint.url])

    model
    |> cast(params, @required_fields, @optional_fields)
    |> put_change(:rendered_content, inline_result.out)
  end
end
