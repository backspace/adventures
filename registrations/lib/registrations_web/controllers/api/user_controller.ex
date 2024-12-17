defmodule RegistrationsWeb.ApiUserController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias RegistrationsWeb.JSONAPI.UserView

  action_fallback(RegistrationsWeb.FallbackController)

  def update(conn, %{"id" => id} = params) do
    user = Pow.Plug.current_user(conn)

    case Waydowntown.update_user(user, params) do
      {:ok, updated_user} ->
        conn
        |> put_view(UserView)
        |> render("show.json", data: updated_user, conn: conn, params: params)

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
  end
end
