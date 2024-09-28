defmodule RegistrationsWeb.SpecificationController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias RegistrationsWeb.Owner.SpecificationView

  action_fallback(RegistrationsWeb.FallbackController)

  def index(conn, params) do
    specifications = Waydowntown.list_specifications()
    render(conn, "index.json", %{specifications: specifications, conn: conn, params: params})
  end

  def mine(conn, params) do
    user = Pow.Plug.current_user(conn)
    specifications = Waydowntown.list_specifications_for(user)

    conn
    |> put_view(SpecificationView)
    |> render("index.json", %{specifications: specifications, conn: conn, params: params})
  end

  def update(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)
    specification = Waydowntown.get_specification!(id)

    if specification.creator_id == user.id do
      case Waydowntown.update_specification(specification, params) do
        {:ok, updated_specification} ->
          conn
          |> put_view(SpecificationView)
          |> render("show.json", specification: updated_specification, conn: conn, params: params)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(RegistrationsWeb.ChangesetView)
          |> render("error.json", changeset: changeset)
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{errors: [%{detail: "Unauthorized"}]})
    end
  end
end
