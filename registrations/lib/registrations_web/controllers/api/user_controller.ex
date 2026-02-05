defmodule RegistrationsWeb.ApiUserController do
  use RegistrationsWeb, :controller

  alias Registrations.Waydowntown
  alias RegistrationsWeb.JSONAPI.UserView

  action_fallback(RegistrationsWeb.FallbackController)

  @team_fields ~w(team_emails proposed_team_name risk_aversion)

  def update(conn, params) do
    user = Pow.Plug.current_user(conn)

    result =
      if has_team_fields?(params) do
        Waydowntown.update_user_details(user, params)
      else
        Waydowntown.update_user(user, params)
      end

    case result do
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

  defp has_team_fields?(params) do
    Enum.any?(@team_fields, fn field -> Map.has_key?(params, field) end)
  end
end
