defmodule RegistrationsWeb.SpecificationController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias RegistrationsWeb.Owner.SpecificationView

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    specifications = Waydowntown.list_specifications()
    render(conn, "index.json", %{data: specifications, conn: conn, params: params})
  end

  def mine(conn, params) do
    user = Pow.Plug.current_user(conn)
    specifications = Waydowntown.list_specifications_for(user)

    conn
    |> put_view(SpecificationView)
    |> render("index.json", %{data: specifications, conn: conn, params: params})
  end

  def update(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)
    specification = Waydowntown.get_specification!(id)

    if specification.creator_id == user.id do
      case Waydowntown.update_specification(specification, params) do
        {:ok, updated_specification} ->
          conn
          |> put_view(SpecificationView)
          |> render("show.json", data: updated_specification, conn: conn, params: params)

        {:error, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, &RegistrationsWeb.ErrorHelpers.translate_error/1)

          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            errors:
              Enum.map(errors, fn {field, message} ->
                %{
                  detail: "#{message}",
                  source: %{pointer: "/data/attributes/#{field}"}
                }
              end)
          })
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: [%{detail: "Unauthorized"}]})
    end
  end
end
